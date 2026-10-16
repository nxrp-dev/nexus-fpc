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
       TPCompilerReal,
       node,
       symtype,
       defutil,defcmp,
       nld
       ;

    type
       TTypeConvNodeFlag = (
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
       TTypeConvNodeFlags = set of TTypeConvNodeFlag;

       TTypeConvNode = class(TUnaryNode)
          totypedef   : TDef;
          totypedefderef : TDeref;
          convtype : TConvertType;
          convnodeflags : TTypeConvNodeFlags;
          warn_pointer_to_signed,
          assignment_side: boolean;
          constructor create(node : TNode;def:TDef);virtual;
          constructor create_explicit(node : TNode;def:TDef);
          constructor Create_Internal(node : TNode;def:TDef);
          constructor create_proc_to_procvar(node : TNode);
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
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
          procedure second_call_helper(c : TConvertType);
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
          function first_call_helper(c : TConvertType) : TNode;
          function typecheck_call_helper(c : TConvertType) : TNode;
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
       TTypeConvNodeClass = class of TTypeConvNode;

       { common functionality of as-nodes and is-nodes }
       TAsIsNode = class(TBinaryNode)
          protected
           { if non-standard usage of as-nodes is possible, targets can override
           this method and return true in case the conditions are fulfilled }
          function target_specific_typecheck: boolean;virtual;
         public
          function pass_typecheck:TNode;override;
       end;

       TAsNode = class(TAsIsNode)
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
          constructor Create_Internal(l,r : TNode);virtual;
          function pass_1 : TNode;override;
          function dogetcopy: TNode;override;
          function docompare(p: TNode): boolean; override;
          destructor Destroy; override;
       end;
       TAsNodeClass = class of TAsNode;

       TIsNode = class(TAsIsNode)
          constructor create(l,r : TNode);virtual;
          constructor Create_Internal(l,r : TNode);virtual;
          function pass_1 : TNode;override;
          procedure pass_generate_code;override;
       end;
       TIsNodeClass = class of TIsNode;

    var
       CTypeConvNode : TTypeConvNodeClass = TTypeConvNode;
       CAsNode : TAsNodeClass = TAsNode;
       CIsNode : TIsNodeClass=TIsNode;

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
      GlobType,Systems,ConstExp,compinnr,
      CUtils,Verbose,Globals,WideStr,PPU,
      symconst,symdef,SymSym,symcpu,SymTable,
      ncon,ncal,nset,nadd,nmem,nmat,nbas,nutils,ninl,nflw,
      psub,
      cgbase,ProcInfo,
      htypechk,blockutl,pparautl,procdefutil,pass_1,CPUInfo;


{*****************************************************************************
                                   Helpers
*****************************************************************************}
    type
      TTypeConvNodeType = (tct_implicit,tct_explicit,tct_internal);

    procedure do_inserttypeconv(var p: TNode;def: TDef; convtype: TTypeConvNodeType);

      begin
        if not Assigned(p.resultdef) then
         begin
           TypeCheckPass(p);
           if CodeGenError then
            exit;
         end;


        { Preserve definition kinds and bitpacked access widths when removing casts. }
        if Equal_Defs(p.resultdef,def) and
           (p.resultdef.typ=def.typ) and
           not is_bitpacked_access(p) and
           { result of a hardware vector node must remain a hardware
             vector of the same kind (will match to tc_equal with regular arrays
             of same dimension/eledef) }
           not((p.resultdef.typ=arraydef) and
               TArrayDef(p.resultdef).Is_HWVector) and
           ((p.blocktype=bt_const) or
            not CTypeConvNode.target_specific_need_equal_typeconv(p.resultdef,def)) then
          begin
            { don't replace encoded string constants to rawbytestring encoding.
              preserve the codepage }
            if not (Is_RawByteString(def) and (p.nodetype=stringconstn)) then
              p.resultdef:=def
          end
        else
         begin
           case convtype of
             tct_implicit:
               p:=CTypeConvNode.create(p,def);
             tct_explicit:
               p:=CTypeConvNode.create_explicit(p,def);
             tct_internal:
               p:=CTypeConvNode.Create_Internal(p,def);
           end;
           if not (nf_internal in p.flags) and Is_Currency(def) then
             Include(p.flags, nf_is_currency);
           p.fileinfo:=TTypeConvNode(p).left.fileinfo;
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
        constp      : TSetConstNode;
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
                if TOrdDef(def).OrdType=uwidechar then
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
                           hdef:=U8IntType
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

        procedure do_set(pos : LongInt);
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
        l : LongInt;
        lr,hr : TConstExprInt;
        hp : TArrayConstructorNode;
        oldfilepos: TFilePosInfo;
        first: Boolean;
      begin
        { keep in sync with arrayconstructor_can_be_set }
        if p.nodetype<>arrayconstructorn then
          InternalError(200205105);
        { A generic body is parsed again when specializing. Do not lower a set
          constructor before its element types are known: even a fixed set
          destination can contain expressions whose type is a parameter. }
        if Assigned(CurrentProcInfo) and
           (df_generic in CurrentProcInfo.procdef.DefOptions) then
          begin
            hp:=TArrayConstructorNode(p);
            while Assigned(hp) and Assigned(hp.left) do
              begin
                TypeCheckPass(hp.left);
                if hp.left.nodetype=arrayconstructorrangen then
                  begin
                    p2:=TArrayConstructorRangeNode(hp.left).left;
                    p3:=TArrayConstructorRangeNode(hp.left).right;
                  end
                else
                  begin
                    p2:=hp.left;
                    p3:=nil;
                  end;
                if Is_TypeParam(p2.resultdef) or
                   (Assigned(p3) and Is_TypeParam(p3.resultdef)) then
                  begin
                    { Keep a set-typed placeholder so surrounding set operators
                      can still be checked while parsing the template. }
                    new(constset);
                    constset^:=[];
                    constp:=CSetConstNode.create(nil,CSetDef.create(nil,0,0,true));
                    constp.value_set:=constset;
                    result:=constp;
                    TypeCheckPass(result);
                    if freep then
                      p.free;
                    exit;
                  end;
                hp:=TArrayConstructorNode(hp.right);
              end;
          end;
        new(constset);
        constset^:=[];
        hdef:=nil;
        { make sure to set constsetlo correctly for empty sets }
        if Assigned(TArrayConstructorNode(p).left) then
          constsetlo:=high(aint)
        else
          constsetlo:=0;
        constsethi:=0;
        constp:=CSetConstNode.create(nil,hdef);
        constp.value_set:=constset;
        result:=constp;
        hp:=TArrayConstructorNode(p);
        if Assigned(hp.left) then
         begin
           first:=true;
           while Assigned(hp) do
            begin
              p4:=nil; { will contain the tree to create the set }
              { split a range into p2 and p3 }
              if hp.left.nodetype=arrayconstructorrangen then
               begin
                 p2:=TArrayConstructorRangeNode(hp.left).left;
                 p3:=TArrayConstructorRangeNode(hp.left).right;
                 TArrayConstructorRangeNode(hp.left).left:=nil;
                 TArrayConstructorRangeNode(hp.left).right:=nil;
               end
              else
               begin
                 p2:=hp.left;
                 hp.left:=nil;
                 p3:=nil;
               end;
              TypeCheckPass(p2);
              set_varstate(p2,vs_read,[vsf_must_be_valid]);
              if Assigned(p3) then
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
                    if Is_WideChar(p2.resultdef) then
                      begin
                        if Block_Type<>bt_const then
                          inserttypeconv(p2,CAnsiCharType);
                        if (p2.nodetype<>ordconstn) and not (m_default_unicodestring in CurrentSettings.ModeSwitches) then
                          IncompatibleTypes(CWideCharType,CAnsiCharType);
                      end;

                    GetRange(p2.resultdef,lr,hr);
                    if Assigned(p3) then
                     begin
                       if Is_WideChar(p3.resultdef) then
                         begin
                           if Block_Type<>bt_const then
                             inserttypeconv(p3,CAnsiCharType);
                           if (p3.nodetype<>ordconstn) and not (m_default_unicodestring in CurrentSettings.ModeSwitches) then
                             begin
                               CurrentFilePos:=p3.fileinfo;
                               IncompatibleTypes(CWideCharType,CAnsiCharType);
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
                       if Assigned(hdef) and not(Equal_Defs(hdef,p3.resultdef)) then
                         begin
                            CGMessagePos(p3.fileinfo,type_e_typeconflict_in_set);
                         end
                       else
                         begin
                           if (p2.nodetype=ordconstn) and (p3.nodetype=ordconstn) then
                            begin
                               if not(Is_Integer(p3.resultdef)) then
                                 begin
                                   if not(Assigned(hdef)) and first then
                                     hdef:=p3.resultdef;
                                 end
                               else
                                 begin
                                   inserttypeconv(p3,U8IntType);
                                   inserttypeconv(p2,U8IntType);
                                 end;

                              if TOrdConstNode(p2).Value.svalue>TOrdConstNode(p3).Value.svalue then
                                CGMessagePos(p2.fileinfo,type_w_empty_constant_range_set);
                              for l:=TOrdConstNode(p2).Value.svalue to TOrdConstNode(p3).Value.svalue do
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

                              if Assigned(hdef) then
                                inserttypeconv(p3,hdef)
                              else if first then
                                hdef:=p3.resultdef
                              else
                                inserttypeconv(p3,U8IntType);
                              p4:=CSetElementNode.create(p2,p3);
                            end;
                         end;
                     end
                    else
                     begin
                       { Single value }
                       if p2.nodetype=ordconstn then
                        begin
                          if Assigned(hdef) then
                            inserttypeconv(p2,hdef)
                          else if not(Is_Integer(p2.resultdef)) and first then
                            hdef:=p2.resultdef
                          else
                            inserttypeconv(p2,U8IntType);

                          if not(Is_Integer(p2.resultdef)) then
                            update_constsethi(p2.resultdef,true);

                          do_set(TOrdConstNode(p2).Value.svalue);
                          p2.free;
                          p2 := nil;
                        end
                       else
                        begin
                          update_constsethi(p2.resultdef,false);

                          if Assigned(hdef) then
                            inserttypeconv(p2,hdef)
                          else if not(Is_Integer(p2.resultdef)) and first then
                            hdef:=p2.resultdef
                          else
                            inserttypeconv(p2,U8IntType);

                          p4:=CSetElementNode.create(p2,nil);
                        end;
                     end;
                  end;
                else
                  CGMessage(type_e_ordinal_expr_expected);
              end;
              { insert the set creation tree }
              if Assigned(p4) then
               result:=CAddNode.create(addn,result,p4);
              { load next and dispose current node }
              p2:=hp;
              hp:=TArrayConstructorNode(TArrayConstructorNode(p2).right);
              TArrayConstructorNode(p2).right:=nil;
              if freep then
                p2.free; // no nil needed
              CurrentFilePos:=oldfilepos;
              first:=false;
            end;
          if (hdef=nil) then
            hdef:=U8IntType;
         end
        else
         begin
           { empty set [], only remove node }
           if freep then
             p.free; // no nil needed
         end;
        { set the initial set type }
        constp.resultdef:=CSetDef.create(hdef,constsetlo.svalue,constsethi.svalue,true);
        { determine the resultdef for the tree }
        TypeCheckPass(result);
      end;


    function arrayconstructor_can_be_set(p:TNode):boolean;
      var
        p1,p2 : TNode;
        hdef : TDef;
      begin
        { keep in sync with arrayconstructor_to_set }
        if not Assigned(p) then
          InternalError(2015050401);
        if not Assigned(TArrayConstructorNode(p).left) then
          begin
            if Assigned(TArrayConstructorNode(p).right) then
              InternalError(2015050103);
            result:=true;
          end
        else
          begin
            result:=false;

            hdef:=nil;

            while Assigned(p) do
              begin
                if TArrayConstructorNode(p).left.nodetype=arrayconstructorrangen then
                  begin
                    p1:=TArrayConstructorRangeNode(TArrayConstructorNode(p).left).left;
                    p2:=TArrayConstructorRangeNode(TArrayConstructorNode(p).left).right;
                  end
                else
                  begin
                    p1:=TArrayConstructorNode(p).left;
                    p2:=nil;
                  end;

                case p1.resultdef.typ of
                  orddef,
                  enumdef:
                    begin
                      if Is_WideChar(p1.resultdef) then
                        begin
                          if p1.nodetype<>ordconstn then
                            exit
                          else if (TOrdConstNode(p1).Value.uvalue>high(byte)) and not (m_default_unicodestring in CurrentSettings.ModeSwitches) then
                            exit;
                        end;

                      if Assigned(p2) then
                        begin
                          if Is_WideChar(p2.resultdef) then
                            begin
                              if p2.nodetype<>ordconstn then
                                exit
                              else if (TOrdConstNode(p2).Value.uvalue>high(byte)) and not (m_default_unicodestring in CurrentSettings.ModeSwitches) then
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
                    else if Assigned(hdef) and not Is_Char(hdef) then
                      exit;
                  else
                    exit;
                end;

                p:=TArrayConstructorNode(p).right;
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
           (TStringConstNode(p).cst_type in [cst_conststring,cst_shortstring,cst_longstring]) then
          p:=CTypeConvNode.Create_Internal(p,GetAnsiStringDef)
        else
          case p.resultdef.typ of
            enumdef :
              p:=CTypeConvNode.Create_Internal(p,S32IntType);
            arraydef :
              begin
                if Is_CharArray(p.resultdef) then
                  p:=CTypeConvNode.Create_Internal(p,CharPointerType)
                else
                  if Is_WideCharArray(p.resultdef) then
                    p:=CTypeConvNode.Create_Internal(p,WideCharPointerType)
                else
                  CGMessagePos1(p.fileinfo,type_e_wrong_type_in_array_constructor,p.resultdef.TypeName);
              end;
            orddef :
              begin
                if Is_Integer(p.resultdef) and
                   not(Is_64BitInt(p.resultdef)) then
                  if not(m_delphi in CurrentSettings.ModeSwitches) then
                    p:=CTypeConvNode.create(p,S32IntType)
                  else
                    { delphi doesn't generate a range error when passing a
                      cardinal >= $80000000, but since these are seen as
                      longint on the callee side, this causes data loss;
                      as a result, we require an explicit longint()
                      typecast in FPC mode on the caller side if range
                      checking should be disabled, but not in Delphi mode }
                    p:=CTypeConvNode.Create_Internal(p,S32IntType)
                else if Is_Void(p.resultdef) then
                  CGMessagePos1(p.fileinfo,type_e_wrong_type_in_array_constructor,p.resultdef.TypeName)
                else if iscvarargs and Is_Currency(p.resultdef)
                    and (CurrentSettings.FPUType<>fpu_none) then
                  p:=CTypeConvNode.create(p,S64FloatType);
              end;
            floatdef :
              if not(iscvarargs) then
                begin
                  if not(Is_Currency(p.resultdef)) then
                    p:=CTypeConvNode.create(p,PBestRealType^);
                end
              else
                begin
                  if (is_constrealnode(p) and not(nf_explicit in p.flags)) or
                     ((TargetInfo.system=system_x86_64_win64) and Is_Extended(p.resultdef)) then
                    MessagePos(p.fileinfo,type_w_double_c_varargs);
                  if (TFloatDef(p.resultdef).FloatType in [S32Real,s64currency]) or
                     ((TargetInfo.system=system_x86_64_win64) and Is_Extended(p.resultdef)) or
                     (is_constrealnode(p) and
                      not(nf_explicit in p.flags)) then
                    p:=CTypeConvNode.create(p,S64FloatType);
                end;
            procvardef :
              p:=CTypeConvNode.create(p,VoidPointerType);
            stringdef:
              if iscvarargs then
                p:=CTypeConvNode.create(p,CharPointerType);
            variantdef:
              if iscvarargs then
                CGMessagePos1(p.fileinfo,type_e_wrong_type_in_array_constructor,p.resultdef.TypeName);
            { maybe warn in case it's not using "packrecords c"? }
            recorddef:
              if not iscvarargs then
                CGMessagePos1(p.fileinfo,type_e_wrong_type_in_array_constructor,p.resultdef.TypeName);
            pointerdef:
              ;
            classrefdef:
              if iscvarargs then
                p:=CTypeConvNode.create(p,VoidPointerType);
            objectdef :
              if Is_ObjC_Class_Or_Protocol(p.resultdef) then
                p:=CTypeConvNode.create(p,VoidPointerType)
              else if iscvarargs or
                 Is_Object(p.resultdef) then
                CGMessagePos1(p.fileinfo,type_e_wrong_type_in_array_constructor,p.resultdef.TypeName)
              else
            else
              CGMessagePos1(p.fileinfo,type_e_wrong_type_in_array_constructor,p.resultdef.TypeName);
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
        if (m_nested_procvars in CurrentSettings.ModeSwitches) and
           not(m_tp_procvar in CurrentSettings.ModeSwitches) and
           (todef.typ=procvardef) and
           Is_Nested_PD(TProcVarDef(todef)) and
           (fromnode.nodetype=typeconvn) and
           (TTypeConvNode(fromnode).convtype=tc_proc_2_procvar) and
           not Is_Nested_PD(TProcVarDef(fromnode.resultdef)) and
           (Proc_To_ProcVar_Equal(TProcDef(TTypeConvNode(fromnode).left.resultdef),TProcVarDef(todef),false)>=te_convert_l1) then
          begin
            hp:=fromnode;
            fromnode:=CTypeConvNode.create_proc_to_procvar(TTypeConvNode(fromnode).left);
            TTypeConvNode(fromnode).totypedef:=todef;
            TypeCheckPass(fromnode);
            TTypeConvNode(hp).left:=nil;
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
        if not(m_tp_procvar in CurrentSettings.ModeSwitches) and
           (todef.typ=procvardef) and
           Is_MethodPointer(TProcVarDef(todef)) and
           (fromnode.nodetype=typeconvn) and
           (TTypeConvNode(fromnode).convtype=tc_proc_2_procvar) and
           Is_MethodPointer(fromnode.resultdef) and
           (po_classmethod in TProcVarDef(fromnode.resultdef).ProcOptions) and
           not(po_staticmethod in TProcVarDef(fromnode.resultdef).ProcOptions) and
           (Proc_To_ProcVar_Equal(TProcDef(TTypeConvNode(fromnode).left.resultdef),TProcVarDef(todef),false)>=te_convert_l1) then
          begin
            hp:=fromnode;
            fromnode:=TTypeConvNode(fromnode).left;
            if (fromnode.nodetype=loadn) and
               not Assigned(TLoadNode(fromnode).left) then
              TLoadNode(fromnode).set_mp(CLoadVMTAddrNode.create(CTypeNode.create(TDef(TLoadNode(fromnode).SymTable.DefOwner))));
            fromnode:=CTypeConvNode.create_proc_to_procvar(fromnode);
            TTypeConvNode(fromnode).totypedef:=todef;
            TypeCheckPass(fromnode);
            TTypeConvNode(hp).left:=nil;
            hp.free;
            hp := nil;
            result:=true;
          end;
      end;

{*****************************************************************************
                           TTYPECONVNODE
*****************************************************************************}


    constructor TTypeConvNode.create(node : TNode;def:TDef);

      begin
         inherited create(typeconvn,node);
         convtype:=tc_none;
         convnodeflags:=[];
         totypedef:=def;
         if def=nil then
          InternalError(200103281);
         fileinfo:=node.fileinfo;
         {An attempt to convert the result of a floating point division
          (with the / operator) to an integer type will fail. Give a hint
          to use the div operator.}
         if (node.nodetype=slashn) and (def.typ=orddef) and not(Is_Currency(def)) then
           CGMessage(type_h_use_div_for_int);
         {In expressions like int64:=longint+longint, an integer overflow could be avoided
          by simply converting the operands to int64 first. Give a hint to do this.}
         if (node.nodetype in [addn,subn,muln]) and
            (def.typ=orddef) and (node.resultdef<>nil) and (node.resultdef.typ=orddef) and
            ((TOrdDef(node.resultdef).low>=TOrdDef(def).low) and (TOrdDef(node.resultdef).high<=TOrdDef(def).high)) and
            ((TOrdDef(node.resultdef).low>TOrdDef(def).low) or (TOrdDef(node.resultdef).high<TOrdDef(def).high)) then
           case node.nodetype of
             addn:
               CGMessage1(type_h_convert_add_operands_to_prevent_overflow,def.TypeName);
             subn:
               CGMessage1(type_h_convert_sub_operands_to_prevent_overflow,def.TypeName);
             muln:
               CGMessage1(type_h_convert_mul_operands_to_prevent_overflow,def.TypeName);
             else
               ;
           end;
      end;


    constructor TTypeConvNode.create_explicit(node : TNode;def:TDef);

      begin
         self.create(node,def);
         include(flags,nf_explicit);
      end;


    constructor TTypeConvNode.Create_Internal(node : TNode;def:TDef);

      begin
         self.create(node,def);
         { handle like explicit conversions }
         include(flags,nf_explicit);
         include(flags,nf_internal);
      end;


    constructor TTypeConvNode.create_proc_to_procvar(node : TNode);

      begin
         self.create(node,VoidType);
         convtype:=tc_proc_2_procvar;
      end;


    constructor TTypeConvNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.GetDeref(totypedefderef);
        convtype:=TConvertType(ppufile.GetByte);
        ppufile.GetSet(TPPUSet1(convnodeflags));
      end;


    procedure TTypeConvNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutDeref(totypedefderef);
        ppufile.PutByte(byte(convtype));
        ppufile.PutSet(TPPUSet1(convnodeflags));
      end;


    procedure TTypeConvNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        totypedefderef.build(totypedef);
      end;


    procedure TTypeConvNode.derefimpl;
      begin
        inherited derefimpl;
        totypedef:=TDef(totypedefderef.resolve);
      end;


    function TTypeConvNode.dogetcopy : TNode;
      var
         n : TTypeConvNode;
      begin
         n:=TTypeConvNode(inherited dogetcopy);
         n.convtype:=convtype;
         n.convnodeflags:=convnodeflags;
         n.totypedef:=totypedef;
         n.assignment_side:=assignment_side;
         dogetcopy:=n;
      end;

    procedure TTypeConvNode.printnodeinfo(var t : text);
      var
        first: Boolean;
        i: TTypeConvNodeFlag;
      begin
        inherited printnodeinfo(t);
        write(t,', totypedef = ',totypedef.GetTypeName);
        write(t,', convtype = ',convtype);
        write(t,', assignment_side = ',assignment_side);
        write(t,', convnodeflags = [');
        first:=true;
        for i:=low(TTypeConvNodeFlag) to high(TTypeConvNodeFlag) do
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

    function TTypeConvNode.typecheck_cord_to_pointer : TNode;

      begin
        result:=nil;
        if left.nodetype=ordconstn then
          begin
            if not(nf_explicit in flags) then
              if (TOrdConstNode(left).Value.svalue=0) then
                CGMessage(type_w_zero_to_nil)
              else
                { in Delphi mode, these aren't caught in compare_defs_ext }
                IncompatibleTypes(left.resultdef,resultdef);
            result:=CPointerConstNode.create(TConstPtrUInt(TOrdConstNode(left).Value.uvalue),resultdef);
          end
         else
          InternalError(200104023);
      end;


    function TTypeConvNode.typecheck_chararray_to_string : TNode;
      var
        chartype : string[8];
        newblock : TBlockNode;
        newstat  : TStatementNode;
        restemp  : TTempCreateNode;
      begin
        if Is_WideChar(TArrayDef(left.resultdef).ElementDef) then
          chartype:='widechar'
        else
          chartype:='char';
        if TStringDef(resultdef).StringType=st_shortstring then
          begin
            newblock:=internalstatements(newstat);
            restemp:=CTempCreateNode.create(resultdef,resultdef.Size,tt_persistent,false);
            addstatement(newstat,restemp);
            addstatement(newstat,CCallNode.createintern('fpc_'+chartype+'array_to_shortstr',
              CCallParaNode.create(COrdConstNode.create(
                ord(TArrayDef(left.resultdef).LowRange=0),PasBool1Type,false),
              CCallParaNode.create(left,CCallParaNode.create(
              CTempRefNode.create(restemp),nil)))));
            addstatement(newstat,CTempDeleteNode.create_normal_temp(restemp));
            addstatement(newstat,CTempRefNode.create(restemp));
            result:=newblock;
          end
        else if (TStringDef(resultdef).StringType=st_ansistring) then
          begin
            result:=CCallNode.createinternres(
                      'fpc_'+chartype+'array_to_'+TStringDef(resultdef).StringTypName,
                      CCallParaNode.create(
                        COrdConstNode.create(
                          ord(TArrayDef(left.resultdef).LowRange=0),
                          PasBool1Type,
                          false
                        ),
                        CCallParaNode.create(
                          COrdConstNode.create(
                            GetParaEncoding(resultdef),
                            U16IntType,
                            true
                          ),
                          CCallParaNode.create(left,nil)
                        )
                      ),
                      resultdef
                    );
          end
        else
          result:=CCallNode.createinternres(
            'fpc_'+chartype+'array_to_'+TStringDef(resultdef).StringTypName,
            CCallParaNode.create(COrdConstNode.create(
               ord(TArrayDef(left.resultdef).LowRange=0),PasBool1Type,false),
             CCallParaNode.create(left,nil)),resultdef);
        left:=nil;
      end;


    function TTypeConvNode.typecheck_string_to_chararray : TNode;
      var
        newblock : TBlockNode;
        newstat  : TStatementNode;
        restemp  : TTempCreateNode;
        pchtemp  : pchar;
        arrsize  : TCGInt;
        chartype : string[8];

      begin
        result := nil;
        with TArrayDef(resultdef) do
          begin
            if HighRange<LowRange then
             InternalError(2005010502);
            arrsize := HighRange-LowRange+1;
          end;
        if (left.nodetype = stringconstn) and
           (TStringConstNode(left).cst_type=cst_conststring) then
           begin
             if (m_iso in CurrentSettings.ModeSwitches) and (arrsize<>TStringConstNode(left).len) and
                Is_Char(TArrayDef(resultdef).ElementDef) then
               Message2(type_w_array_size_does_not_match_size_of_constant_string,ToStr(TStringConstNode(left).len),ToStr(arrsize));
             { if the array of char is large enough we can use the string
               constant directly. This is handled in ncgcnv }
             if (arrsize>=TStringConstNode(left).len) and
                Is_Char(TArrayDef(resultdef).ElementDef) then
               begin
                 { pad the constant string with #0 to the array len }
                 { (2.0.x compatible)                               }
                 if (arrsize>TStringConstNode(left).len) then
                   begin
                     pchtemp:=ConcatAnsiStrings(TStringConstNode(left).asconstpchar,pchar(StringOfChar(#0,arrsize-TStringConstNode(left).len)),TStringConstNode(left).len,arrsize-TStringConstNode(left).len);
                     left.free;
                     left:=CStringConstNode.createpchar(pchtemp,arrsize,nil);
                     FreeMem(pchtemp);
                     TypeCheckPass(left);
                   end;
                 exit;
               end;
             { Convert to wide/short/ansistring and call default helper }
             if Is_WideChar(TArrayDef(resultdef).ElementDef) then
               inserttypeconv(left,CUnicodeStringType)
             else
               begin
                 if TStringConstNode(left).len>255 then
                   inserttypeconv(left,GetAnsiStringDef)
                 else
                   inserttypeconv(left,CShortStringType);
               end;
           end;
        if Is_WideChar(TArrayDef(resultdef).ElementDef) then
          chartype:='widechar'
        else
          chartype:='char';
        newblock:=internalstatements(newstat);
        restemp:=CTempCreateNode.create(resultdef,resultdef.Size,tt_persistent,false);
        addstatement(newstat,restemp);
        addstatement(newstat,CCallNode.createintern('fpc_'+TStringDef(left.resultdef).StringTypName+
          '_to_'+chartype+'array',CCallParaNode.create(left,CCallParaNode.create(
          CTempRefNode.create(restemp),nil))));
        addstatement(newstat,CTempDeleteNode.create_normal_temp(restemp));
        addstatement(newstat,CTempRefNode.create(restemp));
        result:=newblock;
        left:=nil;
      end;


    function TTypeConvNode.typecheck_char_to_string : TNode;
      var
        procname: string[31];
        para : TCallParaNode;
        hp : TStringConstNode;
        ws : TCompilerWideString;
        sa : AnsiString;
        cw : TCompilerWideChar;
        l : SizeUInt;
        exprtype : TDef;
      begin
         result:=nil;
         sa:='';
         if (left.nodetype=ordconstn) and
            ((TStringDef(resultdef).StringType in [st_widestring,st_unicodestring,st_ansistring]) or
             (TOrdDef(left.resultdef).OrdType in [uchar,uwidechar])) then
           begin
              if (TStringDef(resultdef).StringType in [st_widestring,st_unicodestring]) then
               begin
                 InitWideString(ws);
                 if TOrdDef(left.resultdef).OrdType=uwidechar then
                   ConcatWideStringChar(ws,TCompilerWideChar(TOrdConstNode(left).Value.uvalue))
                 else
                   ConcatWideStringChar(ws,ASCIIChar2Unicode(chr(TOrdConstNode(left).Value.uvalue)));
                 hp:=CStringConstNode.createunistr(ws);
                 hp.changestringtype(resultdef);
                 DoneWideString(ws);
               end
              else
                begin
                  if (TOrdDef(left.resultdef).OrdType=uwidechar) then
                    begin
                      if not((CurrentSettings.SourceCodePage=CP_UTF8) or
                             ((TStringDef(resultdef).StringType=st_ansistring) and
                              (TStringDef(resultdef).encoding=CP_UTF8))) then
                        begin
                          if TOrdConstNode(left).Value.uvalue>127 then
                            begin
                              Message(type_w_unicode_data_loss);
                              // compiler has different codepage than a system running an application
                              // to prevent wrong codepage and data loss we are converting unicode char
                              // using a helper routine. This is not delphi compatible behavior.
                              // Delphi converts UniocodeChar to ansistring at the compile time
                              // old behavior:
                              // hp:=cstringconstnode.createstr(unicode2asciichar(tcompilerwidechar(tordconstnode(left).value.uvalue)));
                              para:=CCallParaNode.create(left,nil);
                              if TStringDef(resultdef).StringType=st_ansistring then
                                para:=CCallParaNode.create(COrdConstNode.create(GetParaEncoding(resultdef),U16IntType,true),para);
                              result:=CCallNode.createinternres('fpc_uchar_to_'+TStringDef(resultdef).StringTypName,
                                para,resultdef);
                              left:=nil;
                              exit;
                            end
                          else
                            hp:=CStringConstNode.createstr(Unicode2ASCIIChar(TCompilerWideChar(TOrdConstNode(left).Value.uvalue)));
                        end
                      else
                        begin
                          cw:=TCompilerWideChar(TOrdConstNode(left).Value.uvalue);
                          SetLength(sa,5);
                          l:=UnicodeToUtf8(@(sa[1]),Length(sa),@cw,1);
                          SetLength(sa,l-1);
                          hp:=CStringConstNode.createstr(sa);
                          { explicitly set the type of string constant to avoid unnecessary conversion }
                          if (TStringDef(resultdef).StringType=st_ansistring) and
                             (TStringDef(resultdef).encoding=CP_UTF8) then
                            begin
                              hp.cst_type:=cst_ansistring;
                              hp.resultdef:=resultdef;
                            end;
                        end
                    end
                  else
                    hp:=CStringConstNode.createstr(chr(TOrdConstNode(left).Value.uvalue));
                  { output string consts in local ansistring encoding }
                  if Is_AnsiString(resultdef) and ((TStringDef(resultdef).encoding=0) or (TStringDef(resultdef).encoding=Globals.CP_NONE)) then
                    TStringConstNode(hp).changestringtype(GetAnsiStringDef)
                  else
                    TStringConstNode(hp).changestringtype(resultdef);
                end;
              result:=hp;
           end
         else
           { shortstrings are handled 'inline' (except for widechars) }
           if (TStringDef(resultdef).StringType<>st_shortstring) or
              (TOrdDef(left.resultdef).OrdType=uwidechar) then
             begin
               { parameter }
               para:=CCallParaNode.create(left,nil);
               { encoding required? }
               if TStringDef(resultdef).StringType=st_ansistring then
                 para:=CCallParaNode.create(COrdConstNode.create(GetParaEncoding(resultdef),U16IntType,true),para);

               { create the procname }
               if TOrdDef(left.resultdef).OrdType<>uwidechar then
                 begin
                   procname:='fpc_char_to_';
                   if TStringDef(resultdef).StringType in [st_widestring,st_unicodestring] then
                     if nf_explicit in flags then
                       Message2(type_w_explicit_string_cast,left.resultdef.TypeName,resultdef.TypeName)
                     else
                       Message2(type_w_implicit_string_cast,left.resultdef.TypeName,resultdef.TypeName);
                 end
               else
                 begin
                   procname:='fpc_uchar_to_';
                   if not (TStringDef(resultdef).StringType in [st_widestring,st_unicodestring]) then
                     if nf_explicit in flags then
                       Message2(type_w_explicit_string_cast_loss,left.resultdef.TypeName,resultdef.TypeName)
                     else
                       Message2(type_w_implicit_string_cast_loss,left.resultdef.TypeName,resultdef.TypeName);
                 end;
               procname:=procname+TStringDef(resultdef).StringTypName;

               { and finally the call }
               result:=CCallNode.createinternres(procname,para,resultdef);
               left := nil;
             end
           else
             begin
               { use at least u16inttype }

               exprtype:=UIntType;

               { create word(byte(char) shl 8 or 1) for little endian machines}
               { and word(byte(char) or 256) for big endian machines          }
               left := CTypeConvNode.Create_Internal(left,exprtype);
               if (TargetInfo.endian = endian_little) then
                 left := CAddNode.create(orn,
                   CShlShrNode.create(shln,left,COrdConstNode.create(8,exprtype,false)),
                   COrdConstNode.create(1,exprtype,false))
               else
                 left := CAddNode.create(orn,left,
                   COrdConstNode.create(1 shl 8,exprtype,false));
               left := CTypeConvNode.Create_Internal(left,U16IntType);
               TypeCheckPass(left);
             end;
      end;

    function TTypeConvNode.typecheck_string_to_string : TNode;
      begin
        result:=nil;
        if (left.nodetype=stringconstn) and
           (((TStringDef(resultdef).StringType=st_ansistring) and
             (TStringDef(resultdef).encoding<>CP_NONE)
            )
           ) and
           (TStringDef(left.resultdef).StringType in [st_unicodestring,st_widestring]) then
          begin
            TStringConstNode(left).changestringtype(resultdef);
            Result:=left;
            left:=nil;
          end
        else if (TStringDef(resultdef).StringType=st_ansistring) and
                (TStringDef(left.resultdef).StringType=st_ansistring) and
                (TStringDef(resultdef).encoding<>TStringDef(left.resultdef).encoding) then
          begin
            result:=CCallNode.createinternres(
                      'fpc_ansistr_to_ansistr',
                      CCallParaNode.create(
                        COrdConstNode.create(
                          TStringDef(resultdef).encoding,
                          U16IntType,
                          true
                        ),
                        CCallParaNode.create(left,nil)
                      ),
                      resultdef
                    );
            left:=nil;
          end
        else if (left.nodetype=stringconstn) and
                (TStringDef(left.resultdef).StringType in [st_unicodestring,st_widestring]) and
                (TStringDef(resultdef).StringType=st_shortstring) then
          begin
            if not HasNonASCIIChars(TStringConstNode(left).ValueWS) then
              begin
                TStringConstNode(left).changestringtype(resultdef);
                Result:=left;
                left:=nil;
              end;
          end
        else if (TStringDef(left.resultdef).StringType in [st_unicodestring,st_widestring]) and
                not (TStringDef(resultdef).StringType in [st_unicodestring,st_widestring]) then
          begin
            if nf_explicit in flags then
              Message2(type_w_explicit_string_cast_loss,left.resultdef.TypeName,resultdef.TypeName)
            else
              Message2(type_w_implicit_string_cast_loss,left.resultdef.TypeName,resultdef.TypeName);
          end
        else if not (TStringDef(left.resultdef).StringType in [st_unicodestring,st_widestring]) and
                (TStringDef(resultdef).StringType in [st_unicodestring,st_widestring]) then
          begin
            if nf_explicit in flags then
              Message2(type_w_explicit_string_cast,left.resultdef.TypeName,resultdef.TypeName)
            else
              Message2(type_w_implicit_string_cast,left.resultdef.TypeName,resultdef.TypeName);
          end
      end;

    function TTypeConvNode.typecheck_char_to_chararray : TNode;
      begin
        result:=nil;
      end;


    function TTypeConvNode.typecheck_char_to_char : TNode;
      var
        hp : TOrdConstNode;
      begin
         result:=nil;
         if (left.nodetype=ordconstn) and
            ((TOrdDef(resultdef).OrdType<>uchar) or
             (TOrdDef(left.resultdef).OrdType<>uwidechar) or
             (CurrentSettings.SourceCodePage<>CP_UTF8))
         then
           begin
             if (TOrdDef(resultdef).OrdType=uchar) and
                (TOrdDef(left.resultdef).OrdType=uwidechar) and
                (CurrentSettings.SourceCodePage<>CP_UTF8) then
              begin
                if TOrdConstNode(left).Value.uvalue>127 then
                  Message(type_w_unicode_data_loss);
                hp:=COrdConstNode.create(
                      ord(Unicode2ASCIIChar(TCompilerWideChar(TOrdConstNode(left).Value.uvalue))),
                      CAnsiCharType,true);
                result:=hp;
              end
             else if (TOrdDef(resultdef).OrdType=uwidechar) and
                     (TOrdDef(left.resultdef).OrdType=uchar) then
              begin
                hp:=COrdConstNode.create(
                      ASCIIChar2Unicode(chr(TOrdConstNode(left).Value.uvalue)),
                      CWideCharType,true);
                result:=hp;
              end
             else
              InternalError(200105131);
             exit;
           end;
      end;


    function TTypeConvNode.typecheck_int_to_int : TNode;
      var
        v : TConstExprInt;
        n : TNode;
        SetCurFlag: Boolean;
      begin
        SetCurFlag:=False;
        result:=nil;
        if left.nodetype=ordconstn then
         begin
           v:=TOrdConstNode(left).Value;
           if Is_Currency(resultdef) and
              (nf_is_currency in flags) and
              not(nf_internal in flags) then
             begin
               if not(nf_is_currency in left.flags) then
                 v:=v*10000;
               SetCurFlag:=True;
             end;
           if (resultdef.typ=pointerdef) then
             result:=CPointerConstNode.create(TConstPtrUInt(v.uvalue),resultdef)
           else
             begin
               if (nf_is_currency in left.flags) and
                 Is_Currency(left.resultdef) then
                 begin
                  if not(nf_internal in flags) and
                    not(nf_is_currency in flags) then
                    v:=v div 10000;
                 end
               else if (resultdef.typ in [orddef,enumdef]) then
                 AdaptRange(resultdef,v,([nf_internal,nf_absolute]*flags)<>[],nf_explicit in flags,cs_check_range in LocalSwitches);
               result:=COrdConstNode.create(v,resultdef,false);
             end;

           if SetCurFlag then
             Include(result.flags, nf_is_currency);
         end
        else if left.nodetype=pointerconstn then
         begin
           v:=TPointerConstNode(left).Value;
           if (resultdef.typ=pointerdef) then
             result:=CPointerConstNode.create(v.uvalue,resultdef)
           else
             begin
               if (nf_is_currency in flags) and
                 Is_Currency(resultdef) and
                  not(nf_internal in flags) then
                 v:=v*10000;
               result:=COrdConstNode.create(v,resultdef,false);
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
              n:=GetCopy;
              result:=CAddNode.create(muln,n,COrdConstNode.create_currency_scalar(resultdef));
              include(result.flags,nf_is_currency);
              exclude(n.flags,nf_is_currency);
              include(n.flags,nf_internal);
            end
           else if not (nf_is_currency in flags) and (nf_is_currency in left.flags) then
            begin
              n:=GetCopy;
              result:=CModDivNode.create(divn,n,COrdConstNode.create_currency_scalar(resultdef));
              include(n.flags,nf_is_currency);
              include(n.flags,nf_internal);
            end;
         end;
      end;


    function TTypeConvNode.typecheck_int_to_real : TNode;
      var
        rv : BestReal;
        n : TNode;
        SetCurFlag: Boolean;
      begin
        result:=nil;
        if left.nodetype=ordconstn then
         begin
           rv:=TOrdConstNode(left).Value;

           if not(nf_internal in flags) then
             begin
               SetCurFlag:=(nf_is_currency in flags); { Make sure the flag gets preserved }

               if (nf_is_currency in flags) and Is_Currency(resultdef) then
                 begin
                   if not(nf_is_currency in left.flags) then
                     begin
                       rv:=rv*BestReal(10000.0);
                       SetCurFlag:=True;
                     end
                 end
               else if Is_Currency(left.resultdef) and
                 (nf_is_currency in left.flags) and
                 not SetCurFlag then
                 rv:=rv/BestReal(10000.0);
             end
           else
             SetCurFlag:=False;

           result:=CRealConstNode.create(rv,resultdef);
           if SetCurFlag then
             include(result.flags,nf_is_currency)
         end
        else if not(nf_internal in flags) then
         begin
           { multiply by 10000 for currency. We need to use getcopy to pass
             the argument because the current node is always disposed. Only
             inserting the multiply in the left node is not possible because
             it'll get in an infinite loop to convert int->currency }
           if Is_Currency(resultdef) and
             not (nf_is_currency in left.flags) then
            begin
              n:=GetCopy;
              Exclude(n.flags,nf_is_currency);
              result:=CAddNode.create(muln,n,CRealConstNode.create_currency_scalar(resultdef));
              Include(result.flags,nf_is_currency);
            end
           else if Is_Currency(left.resultdef) and
            (nf_is_currency in left.flags) and
            not (nf_is_currency in flags) then
            begin
              n:=GetCopy;
              Include(n.flags,nf_is_currency);
              result:=CAddNode.create(slashn,n,CRealConstNode.create_currency_scalar(resultdef));
            end;
         end;
      end;


    function TTypeConvNode.typecheck_real_to_currency : TNode;
      var
        n: TNode;
      begin
        if not Is_Currency(resultdef) then
          InternalError(200304221);

        { Convert constants directly, else call Round() }
        if left.nodetype=realconstn then
          begin
            result:=COrdConstNode.create(TRealConstNode(left).CurrencyScaledValue,resultdef,false);
            include(result.flags,nf_is_currency);
          end
        else
          begin
            if not (nf_is_currency in left.flags) then
              begin
                left:=CAddNode.create(muln,left,CRealConstNode.create_currency_scalar(left.resultdef));
                include(left.flags,nf_is_currency);
              end;

            result:=CInlineNode.create(in_round_real,false,left);
            include(result.flags,nf_is_currency);
            { Internal type cast to currency }
            result:=CTypeConvNode.Create_Internal(result,S64CurrencyType);
            include(result.flags,nf_is_currency);
            left:=nil;
          end;
      end;


    function TTypeConvNode.typecheck_real_to_real : TNode;
      begin
         result:=nil;
         if not(nf_internal in flags) then
           begin
             if not (nf_is_currency in flags) and not(Is_Currency(resultdef))
               and (nf_is_currency in left.flags) and Is_Currency(left.resultdef) then
               begin
                 left:=CAddNode.Create_Internal(slashn,left,CRealConstNode.create_currency_scalar(left.resultdef));
                 TypeCheckPass(left);
               end
             else
               if (nf_is_currency in flags) and Is_Currency(resultdef) and
                 not (nf_is_currency in left.flags) then { Regardless of whether or not the type is Currency }
                 begin
                   left:=CAddNode.Create_Internal(muln,left,CRealConstNode.create_currency_scalar(left.resultdef));
                   include(left.flags,nf_is_currency);
                   TypeCheckPass(left);
                 end;
             { comp is handled by the fpu but not a floating type point }
             if Is_FPUComp(resultdef) and not(Is_FPUComp(left.resultdef)) and
               not (nf_explicit in flags) then
               Message(type_w_convert_real_2_comp);
           end;
      end;


    function TTypeConvNode.typecheck_cchar_to_pchar : TNode;

      begin
         result:=nil;
         { handle any constants via cunicodestringtype because the compiler
           cannot convert arbitrary unicodechar constants at compile time to
           a shortstring (since it doesn't know the code page to use) }
         inserttypeconv(left,CUnicodeStringType);
         { evaluate again, reset resultdef so the convert_typ
           will be calculated again and cstring_to_pchar will
           be used for further conversion }
         convtype:=tc_none;
         result:=pass_typecheck;
      end;


    function TTypeConvNode.typecheck_cstring_to_pchar : TNode;

      begin
         result:=nil;
         if Is_PWideChar(resultdef) then
           inserttypeconv(left,CUnicodeStringType)
         else
           if Is_PChar(resultdef) and
              (Is_WideString(left.resultdef) or
               Is_UnicodeString(left.resultdef)) then
             begin
               inserttypeconv(left,GetAnsiStringDef);
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


    function TTypeConvNode.typecheck_cstring_to_int : TNode;
      var
        fcc : cardinal;
        pb  : PByte;
      begin
         result:=nil;
         if left.nodetype<>stringconstn then
           InternalError(200510012);
         if (m_mac in CurrentSettings.ModeSwitches) and
            Is_Integer(resultdef) and
            (TStringConstNode(left).cst_type=cst_conststring) and
            (TStringConstNode(left).len=4) then
           begin
             pb:=PByte(TStringConstNode(left).asconstpchar);
             fcc:=(pb[0] shl 24) or (pb[1] shl 16) or (pb[2] shl 8) or pb[3];
             result:=COrdConstNode.create(fcc,U32IntType,false);
           end
         else
           CGMessage2(type_e_illegal_type_conversion,left.resultdef.TypeName,resultdef.TypeName);
      end;


    function TTypeConvNode.typecheck_arrayconstructor_to_set : TNode;
      var
        hp : TNode;
      begin
        result:=nil;
        if left.nodetype<>arrayconstructorn then
         InternalError(5546);
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
              result:=CTypeConvNode.create_explicit(hp,totypedef)
            else if nf_internal in flags then
              result:=CTypeConvNode.Create_Internal(hp,totypedef)
            else
              result:=CTypeConvNode.create(hp,totypedef);
          end
        else
          result:=hp;
      end;


    function TTypeConvNode.typecheck_set_to_set : TNode;
      begin
        result:=nil;
        { constant sets can be converted by changing the type only }
        if (left.nodetype=setconstn) then
         begin
           if (cs_check_range in CurrentSettings.LocalSwitches) and (TSetConstNode(left).elements>0) and ((TSetConstNode(left).low<TSetDef(resultdef).SetLow) or (TSetConstNode(left).high>TSetDef(resultdef).SetMax)) then
             Message(parser_e_range_check_error);

           left.resultdef:=resultdef;
           result:=left;
           left:=nil;
           exit;
         end;
      end;


    function TTypeConvNode.typecheck_pchar_to_string : TNode;
      var
        newblock : TBlockNode;
        newstat  : TStatementNode;
        restemp  : TTempCreateNode;
      begin
        if TStringDef(resultdef).StringType=st_shortstring then
          begin
            newblock:=internalstatements(newstat);
            restemp:=CTempCreateNode.create(resultdef,resultdef.Size,tt_persistent,false);
            addstatement(newstat,restemp);
            addstatement(newstat,CCallNode.createintern('fpc_pchar_to_shortstr',CCallParaNode.create(left,CCallParaNode.create(
              CTempRefNode.create(restemp),nil))));
            addstatement(newstat,CTempDeleteNode.create_normal_temp(restemp));
            addstatement(newstat,CTempRefNode.create(restemp));
            result:=newblock;
          end
        else if TStringDef(resultdef).StringType=st_ansistring then
          result := CCallNode.createinternres(
                      'fpc_pchar_to_'+TStringDef(resultdef).StringTypName,
                      CCallParaNode.create(
                        COrdConstNode.create(GetParaEncoding(resultdef),U16IntType,true),
                        CCallParaNode.create(left,nil)
                      ),
                      resultdef
                    )
        else
          result := CCallNode.createinternres(
            'fpc_pchar_to_'+TStringDef(resultdef).StringTypName,
            CCallParaNode.create(left,nil),resultdef);
        left:=nil;
      end;


    function TTypeConvNode.typecheck_interface_to_string : TNode;
      begin
        if Assigned(TObjectDef(left.resultdef).IIDStr) then
          begin
            if not(oo_has_valid_guid in TObjectDef(left.resultdef).ObjectOptions) then
              CGMessage1(type_e_interface_has_no_name,TObjectDef(left.resultdef).TypeName);
            result:=CStringConstNode.createstr(TObjectDef(left.resultdef).IIDStr^);
            TStringConstNode(result).changestringtype(resultdef);
          end
        else
          InternalError(2013112913);
      end;


    function TTypeConvNode.typecheck_interface_to_guid : TNode;
      begin
        if Assigned(TObjectDef(left.resultdef).IIDGUID) then
          begin
            if not(oo_has_valid_guid in TObjectDef(left.resultdef).ObjectOptions) then
              CGMessage1(type_e_interface_has_no_guid,TObjectDef(left.resultdef).TypeName);
            result:=CGUIDConstNode.create(TObjectDef(left.resultdef).IIDGUID^);
          end
        else
          InternalError(2013112914);
      end;


    function TTypeConvNode.typecheck_dynarray_to_openarray : TNode;
      begin
        if (actualtargetnode(@left)^.nodetype in [pointerconstn,niln]) then
          CGMessage(type_e_no_addr_of_constant);
        { a dynamic array is a pointer to an array, so to convert it to }
        { an open array, we have to dereference it (JM)                 }
        result:=CTypeConvNode.Create_Internal(left,CPointerDef.getreusable(resultdef));
        TypeCheckPass(result);
        { left is reused }
        left:=nil;
        result:=CDerefNode.create(result);
        include(TDerefNode(result).derefnodeflags,drnf_no_checkpointer);
      end;


    function TTypeConvNode.typecheck_pwchar_to_string : TNode;
      var
        newblock : TBlockNode;
        newstat  : TStatementNode;
        restemp  : TTempCreateNode;
      begin
        if TStringDef(resultdef).StringType=st_shortstring then
          begin
            newblock:=internalstatements(newstat);
            restemp:=CTempCreateNode.create(resultdef,resultdef.Size,tt_persistent,false);
            addstatement(newstat,restemp);
            addstatement(newstat,CCallNode.createintern('fpc_pwidechar_to_shortstr',CCallParaNode.create(left,CCallParaNode.create(
              CTempRefNode.create(restemp),nil))));
            addstatement(newstat,CTempDeleteNode.create_normal_temp(restemp));
            addstatement(newstat,CTempRefNode.create(restemp));
            result:=newblock;
          end
        else if TStringDef(resultdef).StringType=st_ansistring then
          begin
            result:=CCallNode.createinternres(
                        'fpc_pwidechar_to_'+TStringDef(resultdef).StringTypName,
                         CCallParaNode.create(
                           COrdConstNode.create(
                             GetParaEncoding(resultdef),
                             U16IntType,
                             true
                           ),
                           CCallParaNode.create(left,nil)
                         ),
                         resultdef
                      );
          end
        else
          result := CCallNode.createinternres(
            'fpc_pwidechar_to_'+TStringDef(resultdef).StringTypName,
            CCallParaNode.create(left,nil),resultdef);
        left:=nil;
      end;


    function TTypeConvNode.typecheck_variant_to_dynarray : TNode;
      begin
        result := CCallNode.createinternres(
          'fpc_variant_to_dynarray',
          CCallParaNode.create(CAddrNode.Create_Internal(CRTTINode.create(TStoredDef(resultdef),initrtti,rdt_normal)),
            CCallParaNode.create(left,nil)
          ),resultdef);
        TypeCheckPass(result);
        left:=nil;
      end;


    function TTypeConvNode.typecheck_dynarray_to_variant : TNode;
      begin
        result := CCallNode.createinternres(
          'fpc_dynarray_to_variant',
          CCallParaNode.create(CAddrNode.Create_Internal(CRTTINode.create(TStoredDef(left.resultdef),initrtti,rdt_normal)),
            CCallParaNode.create(CTypeConvNode.create_explicit(left,VoidPointerType),nil)
          ),resultdef);
        TypeCheckPass(result);
        left:=nil;
      end;


    function TTypeConvNode.typecheck_variant_to_interface : TNode;
      begin
        if Def_Is_Related(TObjectDef(resultdef),TObjectDef(Search_System_Type('IDISPATCH').typedef)) then
          result := CCallNode.createinternres(
            'fpc_variant_to_idispatch',
              CCallParaNode.create(left,nil)
            ,resultdef)
        else
          result := CCallNode.createinternres(
            'fpc_variant_to_interface',
              CCallParaNode.create(left,nil)
            ,resultdef);
        TypeCheckPass(result);
        left:=nil;
      end;


    function TTypeConvNode.typecheck_interface_to_variant : TNode;
      begin
        if Def_Is_Related(TObjectDef(left.resultdef),TObjectDef(Search_System_Type('IDISPATCH').typedef)) then
          result := CCallNode.createinternres(
            'fpc_idispatch_to_variant',
              CCallParaNode.create(left,nil)
            ,resultdef)
        else
          result := CCallNode.createinternres(
            'fpc_interface_to_variant',
              CCallParaNode.create(left,nil)
            ,resultdef);
        TypeCheckPass(result);
        left:=nil;
      end;


    function TTypeConvNode.typecheck_variant_to_enum : TNode;

      begin
        result := CTypeConvNode.Create_Internal(left,SIntType);
        result := CTypeConvNode.Create_Internal(result,resultdef);
        TypeCheckPass(result);
        { left is reused }
        left := nil;
      end;


    function TTypeConvNode.typecheck_enum_to_variant : TNode;

      begin
        result := CTypeConvNode.Create_Internal(left,SIntType);
        result := CTypeConvNode.Create_Internal(result,CVariantType);
        TypeCheckPass(result);
        { left is reused }
        left := nil;
      end;


    function TTypeConvNode.typecheck_array_2_dynarray : TNode;
      var
        newstatement : TStatementNode;
        temp         : TTempCreateNode;
        temp2        : TTempCreateNode;
      begin
        { create statements with call to getmem+initialize }
        result:=internalstatements(newstatement);

        { create temp for result }
        temp:=CTempCreateNode.create(resultdef,resultdef.Size,tt_persistent,true);
        addstatement(newstatement,temp);

        { get temp for array of lengths }
        temp2:=CTempCreateNode.create(SIntType,SIntType.Size,tt_persistent,false);
        addstatement(newstatement,temp2);

        { one dimensional }
        addstatement(newstatement,CAssignmentNode.create(
            CTempRefNode.create(temp2),
            COrdConstNode.create
               (TArrayDef(left.resultdef).HighRange+1,S32IntType,true)));
        { create call to fpc_dynarr_setlength }
        addstatement(newstatement,CCallNode.createintern('fpc_dynarray_setlength',
            CCallParaNode.create(CAddrNode.Create_Internal
                  (CTempRefNode.create(temp2)),
               CCallParaNode.create(COrdConstNode.create
                  (1,S32IntType,true),
               CCallParaNode.create(CAddrNode.Create_Internal
                  (CRTTINode.create(TStoredDef(resultdef),initrtti,rdt_normal)),
               CCallParaNode.create(
                 CTypeConvNode.Create_Internal(
                   CTempRefNode.create(temp),VoidPointerType),
                 nil))))

          ));
        addstatement(newstatement,CTempDeleteNode.create(temp2));

        { copy ... }
        addstatement(newstatement,CAssignmentNode.create(
          CTypeConvNode.Create_Internal(CDerefNode.create(CTypeConvNode.Create_Internal(CTempRefNode.create(temp),VoidPointerType)),left.resultdef),
          left
        ));
        { left is reused }
        left:=nil;
        { the last statement should return the value as
          location and type, this is done be referencing the
          temp and converting it first from a persistent temp to
          normal temp }
        addstatement(newstatement,CTempDeleteNode.create_normal_temp(temp));
        addstatement(newstatement,CTempRefNode.create(temp));
      end;


    function TTypeConvNode.typecheck_elem_2_openarray : TNode;
      begin
        result:=nil;
      end;


    function TTypeConvNode.typecheck_arrayconstructor_to_dynarray : TNode;
      var
        newstatement,
        assstatement : TStatementNode;
        arrnode : TTempCreateNode;
        temp2 : TTempCreateNode;
        assnode : TNode;
        paracount : integer;
        elemnode : TArrayConstructorNode;
      begin
        { assignment of []? }
        if (
              (left.nodetype=arrayconstructorn) and
              not Assigned(TArrayConstructorNode(left).left)
            ) or
              is_emptyset(left)
            then
          begin
            result:=CNilNode.create;
            exit;
          end;

        if resultdef.typ<>arraydef then
          InternalError(2017050102);

        TArrayConstructorNode(left).force_type(TArrayDef(resultdef).ElementDef);

        result:=internalstatements(newstatement);
        { create temp for result }
        arrnode:=CTempCreateNode.create(totypedef,totypedef.Size,tt_persistent,true);
        addstatement(newstatement,arrnode);

        paracount:=0;

        { create an assignment call for each element }
        assnode:=internalstatements(assstatement);
        if left.nodetype=arrayconstructorrangen then
          InternalError(2016021902);
        elemnode:=TArrayConstructorNode(left);
        while Assigned(elemnode) do
          begin
            { arr[i] := param_i }
            if not Assigned(elemnode.left) then
              InternalError(2017050103);
            addstatement(assstatement,
              CAssignmentNode.create(
                CVecNode.create(
                  CTempRefNode.create(arrnode),
                  COrdConstNode.create(paracount,TArrayDef(totypedef).RangeDef,false)),
                elemnode.left));
            elemnode.left:=nil;
            inc(paracount);
            elemnode:=TArrayConstructorNode(elemnode.right);
            if Assigned(elemnode) and (elemnode.nodetype<>arrayconstructorn) then
              InternalError(2016021903);
          end;

        { get temp for array of lengths }
        temp2:=CTempCreateNode.create_value(SIntType,SIntType.Size,tt_persistent,false,COrdConstNode.create(paracount,S32IntType,true));
        addstatement(newstatement,temp2);

        { create call to fpc_dynarr_setlength }
        addstatement(newstatement,CCallNode.createintern('fpc_dynarray_setlength',
            CCallParaNode.create(CAddrNode.Create_Internal
                  (CTempRefNode.create(temp2)),
               CCallParaNode.create(COrdConstNode.create
                  (1,S32IntType,true),
               CCallParaNode.create(CAddrNode.Create_Internal
                  (CRTTINode.create(TStoredDef(totypedef),initrtti,rdt_normal)),
               CCallParaNode.create(
                 CTypeConvNode.Create_Internal(
                   CTempRefNode.create(arrnode),VoidPointerType),
                 nil))))

          ));
        { add assignment statements }
        addstatement(newstatement,CTempDeleteNode.create(temp2));
        addstatement(newstatement,assnode);
        { the last statement should return the value as
          location and type, this is done be referencing the
          temp and converting it first from a persistent temp to
          normal temp }
        addstatement(newstatement,CTempDeleteNode.create_normal_temp(arrnode));
        addstatement(newstatement,CTempRefNode.create(arrnode));
      end;


    function TTypeConvNode.typecheck_arrayconstructor_to_array : TNode;
      var
        newstatement,
        assstatement : TStatementNode;
        arrnode : TTempCreateNode;
        temp2 : TTempCreateNode;
        assnode : TNode;
        paracount : integer;
        elemnode : TArrayConstructorNode;
      begin
        TArrayConstructorNode(left).force_type(TArrayDef(resultdef).ElementDef);

        result:=internalstatements(newstatement);
        { create temp for result }
        arrnode:=CTempCreateNode.create(totypedef,totypedef.Size,tt_persistent,true);
        addstatement(newstatement,arrnode);

        paracount:=0;

        { create an assignment call for each element }
        assnode:=internalstatements(assstatement);
        if left.nodetype=arrayconstructorrangen then
          InternalError(2020041402);
        elemnode:=TArrayConstructorNode(left);
        while Assigned(elemnode) do
          begin
            { arr[i] := param_i }
            if not Assigned(elemnode.left) then
              InternalError(2020041403);
            addstatement(assstatement,
              CAssignmentNode.create(
                CVecNode.create(
                  CTempRefNode.create(arrnode),
                  COrdConstNode.create(paracount+TArrayDef(totypedef).LowRange,TArrayDef(totypedef).RangeDef,false)),
                elemnode.left));
            elemnode.left:=nil;
            inc(paracount);
            elemnode:=TArrayConstructorNode(elemnode.right);
            if Assigned(elemnode) and (elemnode.nodetype<>arrayconstructorn) then
              InternalError(2020041404);
          end;

        { get temp for array of lengths }
        temp2:=CTempCreateNode.create_value(SIntType,SIntType.Size,tt_persistent,false,COrdConstNode.create(paracount,S32IntType,true));
        addstatement(newstatement,temp2);

        { add assignment statements }
        addstatement(newstatement,CTempDeleteNode.create(temp2));
        addstatement(newstatement,assnode);
        { the last statement should return the value as
          location and type, this is done be referencing the
          temp and converting it first from a persistent temp to
          normal temp }
        addstatement(newstatement,CTempDeleteNode.create_normal_temp(arrnode));
        addstatement(newstatement,CTempRefNode.create(arrnode));
      end;


    function TTypeConvNode._typecheck_int_to_int : TNode;
      begin
        result := typecheck_int_to_int;
      end;


    function TTypeConvNode._typecheck_cord_to_pointer : TNode;
      begin
        result := typecheck_cord_to_pointer;
      end;


    function TTypeConvNode._typecheck_chararray_to_string : TNode;
      begin
        result := typecheck_chararray_to_string;
      end;


    function TTypeConvNode._typecheck_string_to_chararray : TNode;
      begin
        result := typecheck_string_to_chararray;
      end;


    function TTypeConvNode._typecheck_string_to_string: TNode;
      begin
        result := typecheck_string_to_string;
      end;


    function TTypeConvNode._typecheck_char_to_string : TNode;
      begin
        result := typecheck_char_to_string;
      end;


    function TTypeConvNode._typecheck_char_to_chararray : TNode;
      begin
        result := typecheck_char_to_chararray;
      end;


    function TTypeConvNode._typecheck_int_to_real : TNode;
      begin
        result := typecheck_int_to_real;
      end;


    function TTypeConvNode._typecheck_real_to_real : TNode;
      begin
        result := typecheck_real_to_real;
      end;


    function TTypeConvNode._typecheck_real_to_currency : TNode;
      begin
        result := typecheck_real_to_currency;
      end;


    function TTypeConvNode._typecheck_cchar_to_pchar : TNode;
      begin
        result := typecheck_cchar_to_pchar;
      end;


    function TTypeConvNode._typecheck_cstring_to_pchar : TNode;
      begin
        result := typecheck_cstring_to_pchar;
      end;


    function TTypeConvNode._typecheck_cstring_to_int : TNode;
      begin
        result := typecheck_cstring_to_int;
      end;


    function TTypeConvNode._typecheck_char_to_char : TNode;
      begin
        result := typecheck_char_to_char;
      end;


    function TTypeConvNode._typecheck_arrayconstructor_to_set : TNode;
      begin
        result := typecheck_arrayconstructor_to_set;
      end;


    function TTypeConvNode._typecheck_set_to_set : TNode;
      begin
        result := typecheck_set_to_set;
      end;


    function TTypeConvNode._typecheck_pchar_to_string : TNode;
      begin
        result := typecheck_pchar_to_string;
      end;


    function TTypeConvNode._typecheck_interface_to_string : TNode;
      begin
        result := typecheck_interface_to_string;
      end;


    function TTypeConvNode._typecheck_interface_to_guid : TNode;
      begin
        result := typecheck_interface_to_guid;
      end;


    function TTypeConvNode._typecheck_dynarray_to_openarray : TNode;
      begin
        result := typecheck_dynarray_to_openarray;
      end;


    function TTypeConvNode._typecheck_pwchar_to_string : TNode;
      begin
        result := typecheck_pwchar_to_string;
      end;


    function TTypeConvNode._typecheck_variant_to_dynarray : TNode;
      begin
        result := typecheck_variant_to_dynarray;
      end;


    function TTypeConvNode._typecheck_dynarray_to_variant : TNode;
      begin
        result := typecheck_dynarray_to_variant;
      end;


    function TTypeConvNode._typecheck_variant_to_enum : TNode;
      begin
        result := typecheck_variant_to_enum;
      end;


    function TTypeConvNode._typecheck_enum_to_variant : TNode;
      begin
        result := typecheck_enum_to_variant;
      end;


    function TTypeConvNode._typecheck_proc_to_procvar : TNode;
      begin
        result := typecheck_proc_to_procvar;
      end;


    function TTypeConvNode._typecheck_variant_to_interface : TNode;
      begin
        result := typecheck_variant_to_interface;
      end;


    function TTypeConvNode._typecheck_interface_to_variant : TNode;
      begin
        result := typecheck_interface_to_variant;
      end;


    function TTypeConvNode._typecheck_array_2_dynarray : TNode;
      begin
        result := typecheck_array_2_dynarray;
      end;


    function TTypeConvNode._typecheck_elem_2_openarray : TNode;
      begin
        result := typecheck_elem_2_openarray;
      end;


    function TTypeConvNode._typecheck_arrayconstructor_to_dynarray : TNode;
      begin
        result:=typecheck_arrayconstructor_to_dynarray;
      end;


    function TTypeConvNode._typecheck_arrayconstructor_to_array : TNode;
      begin
        result:=typecheck_arrayconstructor_to_array;
      end;


    function TTypeConvNode._typecheck_procvar_to_funcref : TNode;
      begin
        result:=typecheck_procvar_2_funcref;
      end;


    function TTypeConvNode._typecheck_anonproc_to_funcref : TNode;
      begin
        result:=typecheck_anonproc_2_funcref;
      end;


    function TTypeConvNode.target_specific_general_typeconv: boolean;
      begin
        result:=false;
      end;


    function TTypeConvNode.target_specific_explicit_typeconv: boolean;
      begin
        result:=false;
      end;


    class function TTypeConvNode.target_specific_need_equal_typeconv(fromdef, todef: TDef): boolean;
      begin
        result:=false;
      end;


    type
      TSymMapping = record
        oldsym:TSym;
        newsym:TSym;
      end;
      PSymMapping = ^TSymMapping;


    function replace_self_sym(var n:TNode;arg:pointer):TForEachNodeResult;
      var
        mapping : PSymMapping absolute arg;
        ld : TLoadNode;
      begin
        if n.nodetype=loadn then
          begin
            ld:=TLoadNode(n);
            if ld.symtableentry=mapping^.oldsym then
              begin
                ld.symtableentry:=mapping^.newsym;
                { make sure that the node is processed again }
                ld.resultdef:=nil;
                if Assigned(ld.left) then
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


    function TTypeConvNode.typecheck_proc_to_procvar : TNode;

      function is_self_sym(sym:TSym):boolean;
        begin
          result:=(sym.typ in [localvarsym,paravarsym]) and
                    (vo_is_self in TAbstractVarSym(sym).VarOptions);
        end;

      var
        pd : TAbstractProcDef;
        copytype : TProcCopyTyp;
        source: PNode;
        fpsym,
        selfsym,
        sym : TSym;
        mapping : TSymMapping;
        pi : TProcInfo;
        i : LongInt;
      begin
        result:=nil;
        pd:=TAbstractProcDef(left.resultdef);

        { create procvardef (default for create_proc_to_procvar is voiddef,
          but if later a regular inserttypeconvnode() is used to insert a type
          conversion to the actual procvardef, totypedef will be set to the
          real procvartype that we are converting to) }
        if Assigned(totypedef) and
           (totypedef.typ=procvardef) then
          begin
            { have to do this in typecheckpass so that it's triggered for
              typed constant declarations }
            if po_is_block in TProcVarDef(totypedef).ProcOptions then
              begin
                { can only convert from procdef to procvardef, but in the mean
                  time other type conversions may have been inserted (pointers,
                  proc2procvar, ...) }
                source:=actualtargetnode(@left);
                while (source^.nodetype=typeconvn) and
                      (TTypeConvNode(source^).convtype=tc_proc_2_procvar) and
                      (Is_Void(source^.resultdef) or
                       (source^.resultdef.typ=procvardef)) do
                  begin
                    { won't skip proc2procvar }
                    source:=actualtargetnode(@TTypeConvNode(source^).left);
                  end;
                if (source^.nodetype=loadn) and
                   (source^.resultdef.typ=procdef) and
                   not Is_Nested_PD(TProcDef(source^.resultdef)) and
                   not Is_ObjCClass(TDef(source^.resultdef.owner.DefOwner)) then
                  begin
                    result:=generate_block_for_procaddr(TLoadNode(source^));
                    exit;
                  end
                else
                  CGMessage2(type_e_illegal_type_conversion,left.resultdef.TypeName,resultdef.TypeName);
              end
            else if (pd.typ=procdef) and
               (po_anonymous in pd.ProcOptions) then
              begin
                if left.nodetype<>loadn then
                  InternalError(2021062402);
                { get rid of any potential framepointer loading; if it's necessary
                  (for a nested procvar for example) it will be added again }
                if Assigned(TLoadNode(left).left) and (TLoadNode(left).left.nodetype=loadparentfpn) then
                  begin
                    TLoadNode(left).left.free;
                    TLoadNode(left).left:=nil;
                    TLoadNode(left).resultdef:=nil;
                  end;
                if TProcVarDef(totypedef).Is_MethodPointer then
                  begin
                    if Assigned(TProcDef(pd).CapturedSyms) and
                        (
                          (TProcDef(pd).CapturedSyms.count>1) or
                          (
                            (TProcDef(pd).CapturedSyms.count=1) and
                            not is_self_sym(TSym(PCapturedSymInfo(TProcDef(pd).CapturedSyms[0])^.sym))
                          )
                        ) then
                      begin
                        result:=CErrorNode.create;
                        exit;
                      end;

                    { so that insert_self_and_vmt_para correctly inserts the
                      Self, cause it otherwise skips that for anonymous functions }
                    include(pd.ProcOptions,po_methodpointer);
                    { we know this only captures Self, so we can move the
                      anonymous function to normal function level }
                    pd.ParaST.SymTableLevel:=NormalFunctionLevel;
                    TProcDef(pd).LocalST.SymTableLevel:=NormalFunctionLevel;

                    selfsym:=nil;
                    fpsym:=nil;
                    { find the framepointer parameter and an eventual self }
                    for i:=0 to TProcDef(pd).ParaST.SymList.count-1 do
                      begin
                        sym:=TSym(TProcDef(pd).ParaST.SymList[i]);
                        if sym.typ<>paravarsym then
                          continue;
                        if vo_is_parentfp in TParaVarSym(sym).VarOptions then
                          fpsym:=sym;
                        if vo_is_self in TParaVarSym(sym).VarOptions then
                          selfsym:=sym;
                        if Assigned(fpsym) and Assigned(selfsym) then
                          break;
                      end;

                    if Assigned(fpsym) then
                      TProcDef(pd).ParaST.SymList.remove(fpsym);

                    { if we don't have a self parameter already we need to
                      insert a suitable one }

                    if not Assigned(selfsym) then
                      begin
                        { replace the self symbol by the new parameter if it was
                          captured }
                        if Assigned(TProcDef(pd).CapturedSyms) and
                            (TProcDef(pd).CapturedSyms.count>0) then
                          begin
                            if not Assigned(TProcDef(pd).struct) then
                              { we can't use the captured symbol for the struct as that
                                might be the self of a type helper, thus we need to find
                                the parent procinfo that provides the Self }
                              TProcDef(pd).struct:=CurrentProcInfo.get_normal_proc.procdef.struct;
                            if not Assigned(TProcDef(pd).struct) then
                              InternalError(2021062204);

                            insert_self_and_vmt_para(pd);

                            mapping.oldsym:=TSym(PCapturedSymInfo(TProcDef(pd).CapturedSyms[0])^.sym);
                            mapping.newsym:=nil;

                            { find the new self parameter }
                            for i:=0 to TProcDef(pd).ParaST.SymList.count-1 do
                              begin
                                sym:=TSym(TProcDef(pd).ParaST.SymList[i]);
                                if (sym.typ=paravarsym) and (vo_is_self in TParaVarSym(sym).VarOptions) then
                                  begin
                                    mapping.newsym:=sym;

                                    break;
                                  end;
                              end;

                            if not Assigned(mapping.newsym) then
                              InternalError(2021062202);

                            { the anonymous function can only be a direct child of the
                              current_procinfo }
                            pi:=CurrentProcInfo.get_first_nestedproc;
                            while Assigned(pi) do
                              begin
                                if pi.procdef=pd then
                                  break;
                                pi:=TProcInfo(pi.next);
                              end;

                            if not Assigned(pi) then
                              InternalError(2021062203);

                            { replace all uses of the captured Self by the new Self
                              parameter }
                            foreachnodestatic(pm_preprocess,TCGProcInfo(pi).code,@replace_self_sym,@mapping);
                          end
                        else
                          begin
                            { for a nested function of a method struct is already
                              set }
                            if not Assigned(TProcDef(pd).struct) then
                              { simply add a TObject as Self parameter }
                              TProcDef(pd).struct:=Class_TObject;

                            insert_self_and_vmt_para(pd);

                            { there is no self, so load a nil value }
                            TLoadNode(left).set_mp(CNilNode.create);
                          end;
                      end;

                    { the anonymous function no longer adheres to the nested
                      calling convention }
                    exclude(pd.ProcOptions,po_delphi_nested_cc);

                    TProcDef(pd).CalcParas;

                    if not Assigned(TLoadNode(left).left) then
                      TLoadNode(left).set_mp(load_self_node);
                  end
                else if TProcVarDef(totypedef).Is_AddressOnly then
                  begin
                    if Assigned(TProcDef(pd).CapturedSyms) and (TProcDef(pd).CapturedSyms.count>0) then
                      begin
                        result:=CErrorNode.create;
                        exit;
                      end;

                    { remove framepointer and Self parameters }
                    for i:=TProcDef(pd).ParaST.SymList.count-1 downto 0 do
                      begin
                        sym:=TSym(TProcDef(pd).ParaST.SymList[i]);
                        if (sym.typ=paravarsym) and (TParaVarSym(sym).VarOptions*[vo_is_parentfp,vo_is_self]<>[]) then
                          TProcDef(pd).ParaST.SymList.delete(i);
                      end;

                    { the anonymous function no longer adheres to the nested
                      calling convention }
                    exclude(pd.ProcOptions,po_delphi_nested_cc);

                    { we don't need to look through the existing nodes, cause
                      the parameter was never used anyway }
                    TProcDef(pd).CalcParas;
                  end
                else
                  begin
                    { this is a nested function pointer, so ensure that the
                      anonymous function is handled as such }
                    if Assigned(TProcDef(pd).CapturedSyms) and
                        (TProcDef(pd).CapturedSyms.count>0) and
                        (left.nodetype=loadn) then
                      begin
                        TLoadNode(left).left:=CLoadParentFPNode.create(TProcDef(TLoadNode(left).SymTable.DefOwner),lpf_forload);
                        TypeCheckPass(TLoadNode(left).left);

                        pi:=CurrentProcInfo.get_first_nestedproc;
                        while Assigned(pi) do
                          begin
                            if pi.procdef=pd then
                              break;
                            pi:=TProcInfo(pi.next);
                          end;

                        pi.set_needs_parentfp(TProcDef(TLoadNode(left).SymTable.DefOwner).ParaST.SymTableLevel);
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
              not Assigned(TLoadNode(left).left) and
              (not(m_nested_procvars in CurrentSettings.ModeSwitches) or
               not Is_Nested_PD(TAbstractProcDef(TLoadNode(left).resultdef))) then
             copytype:=pc_address_only
           else
             copytype:=pc_normal;
           resultdef:=CProcVarDef.GetReusableProcAddr(pd,copytype);
         end;
      end;


    function TTypeConvNode.typecheck_procvar_2_funcref : TNode;
      var
        capturer : TSym;
        intfdef : TDef;
        ld,blck,hp : TNode;
        stmt : TStatementNode;
      begin
        result:=nil;

        if not(m_tp_procvar in CurrentSettings.ModeSwitches) and
           Is_Invokable(resultdef) and
           (left.nodetype=typeconvn) and
           (TTypeConvNode(left).convtype=tc_proc_2_procvar) and
           Is_MethodPointer(left.resultdef) and
           (po_classmethod in TProcVarDef(left.resultdef).ProcOptions) and
           not(po_staticmethod in TProcVarDef(left.resultdef).ProcOptions) and
           (Proc_To_FuncRef_Equal(TProcDef(TTypeConvNode(left).left.resultdef),TObjectDef(resultdef))>=te_convert_l1) then
          begin
            hp:=left;
            left:=TTypeConvNode(left).left;
            if (left.nodetype=loadn) and
               not Assigned(TLoadNode(left).left) then
              TLoadNode(left).set_mp(CLoadVMTAddrNode.create(CTypeNode.create(TDef(TLoadNode(left).SymTable.DefOwner))));
            left:=CTypeConvNode.create_proc_to_procvar(left);
            TTypeConvNode(left).totypedef:=resultdef;
            TypeCheckPass(left);
            TTypeConvNode(hp).left:=nil;
            hp.free;
            hp := nil;
          end;

        intfdef:=Capturer_Add_ProcVar_Or_Proc(CurrentProcInfo,left,capturer,hp);
        if Assigned(intfdef) then
          begin
            if Assigned(capturer) then
              ld:=CLoadNode.create(capturer,capturer.owner)
            else
              ld:=CNilNode.create;
            result:=CTypeConvNode.Create_Internal(
                      CTypeConvNode.Create_Internal(
                        ld,
                        intfdef),
                      totypedef);
            if Assigned(hp) then
              begin
                blck:=internalstatements(stmt);
                addstatement(stmt,CAssignmentNode.create(hp,left));
                left:=nil;
                addstatement(stmt,result);
                result:=blck;
              end;
          end;
        if not Assigned(result) then
          result:=CErrorNode.create;
      end;


    function TTypeConvNode.typecheck_anonproc_2_funcref : TNode;
      var
        capturer : TSym;
        intfdef : TDef;
        ldnode : TNode;
      begin
        intfdef:=Capturer_Add_Anonymous_Proc(CurrentProcInfo,TProcDef(left.resultdef),capturer);
        if Assigned(intfdef) then
          begin
            if Assigned(capturer) then
              ldnode:=CLoadNode.create(capturer,capturer.owner)
            else
              ldnode:=CNilNode.create;
            result:=CTypeConvNode.Create_Internal(
                      CTypeConvNode.Create_Internal(
                        ldnode,
                        intfdef),
                      totypedef);
          end
        else
          result:=CErrorNode.create;
      end;

    procedure TTypeConvNode.convert_deferred_stmt_expr;
    { A statement expression (if-, case-, try-expression) with anonymous
      functions as values is created without the assignments to its result
      temp, because the type of the temp is only known now (see pstatmnt).
      Retype the temp, add the assignments and typecheck again. }
      var
        stmt : TStatementNode;
        resulttemp : TTempCreateNode;
        valuenode,onnode : TNode;
        i : LongInt;

        procedure assign_to_temp(var n : TNode);
          begin
            if Assigned(n) then
              n:=CAssignmentNode.create(CTempRefNode.create(resulttemp),n);
          end;

      begin
        { skip the nothing node created by internalstatements }
        stmt:=TStatementNode(TBlockNode(left).left);
        while stmt.left.nodetype=nothingn do
          stmt:=TStatementNode(stmt.right);

        resulttemp:=TTempCreateNode(stmt.left);
        resulttemp.tempinfo^.typedef:=resultdef;
        resulttemp.Size:=resultdef.Size;
        left.resultdef:=nil;

        { the statement computing the value }
        stmt:=TStatementNode(stmt.right);
        valuenode:=stmt.left;
        case valuenode.nodetype of
          ifn:
            begin
              assign_to_temp(TIfNode(valuenode).right);
              assign_to_temp(TIfNode(valuenode).t1);
              valuenode.resultdef:=nil;
            end;
          casen:
            begin
              for i:=0 to TCaseNode(valuenode).blocks.count-1 do
                assign_to_temp(PCaseBlock(TCaseNode(valuenode).blocks[i])^.statement);
              assign_to_temp(TCaseNode(valuenode).elseblock);
              valuenode.resultdef:=nil;
            end;
          tryexceptn:
            begin
              assign_to_temp(TTryExceptNode(valuenode).left);
              onnode:=TTryExceptNode(valuenode).right;
              while Assigned(onnode) and (onnode.nodetype=onn) do
                begin
                  assign_to_temp(TOnNode(onnode).right);
                  onnode:=TOnNode(onnode).left;
                end;
              assign_to_temp(TTryExceptNode(valuenode).t1);
              valuenode.resultdef:=nil;
            end;
          else
            { simplified to a single value, e.g. constant condition }
            assign_to_temp(stmt.left);
        end;

        { the temp delete and temp ref }
        stmt:=TStatementNode(stmt.right);
        while Assigned(stmt) do
          begin
            stmt.left.resultdef:=nil;
            stmt:=TStatementNode(stmt.right);
          end;

        TypeCheckPass(left);
      end;

    function TTypeConvNode.typecheck_call_helper(c : TConvertType) : TNode;
      const
         resultdefconvert : array[TConvertType] of pointer = (
          {none} nil,
          {equal} nil,
          {not_possible} nil,
          { string_2_string } @TTypeConvNode._typecheck_string_to_string,
          { char_2_string } @TTypeConvNode._typecheck_char_to_string,
          { char_2_chararray } @TTypeConvNode._typecheck_char_to_chararray,
          { pchar_2_string } @TTypeConvNode._typecheck_pchar_to_string,
          { cchar_2_pchar } @TTypeConvNode._typecheck_cchar_to_pchar,
          { cstring_2_pchar } @TTypeConvNode._typecheck_cstring_to_pchar,
          { cstring_2_int } @TTypeConvNode._typecheck_cstring_to_int,
          { ansistring_2_pchar } nil,
          { string_2_chararray } @TTypeConvNode._typecheck_string_to_chararray,
          { chararray_2_string } @TTypeConvNode._typecheck_chararray_to_string,
          { array_2_pointer } nil,
          { pointer_2_array } nil,
          { int_2_int } @TTypeConvNode._typecheck_int_to_int,
          { int_2_bool } nil,
          { bool_2_bool } nil,
          { bool_2_int } nil,
          { real_2_real } @TTypeConvNode._typecheck_real_to_real,
          { int_2_real } @TTypeConvNode._typecheck_int_to_real,
          { real_2_currency } @TTypeConvNode._typecheck_real_to_currency,
          { proc_2_procvar } @TTypeConvNode._typecheck_proc_to_procvar,
          { nil_2_methodprocvar } nil,
          { arrayconstructor_2_set } @TTypeConvNode._typecheck_arrayconstructor_to_set,
          { set_to_set } @TTypeConvNode._typecheck_set_to_set,
          { cord_2_pointer } @TTypeConvNode._typecheck_cord_to_pointer,
          { intf_2_string } @TTypeConvNode._typecheck_interface_to_string,
          { intf_2_guid } @TTypeConvNode._typecheck_interface_to_guid,
          { class_2_intf } nil,
          { char_2_char } @TTypeConvNode._typecheck_char_to_char,
          { dynarray_2_openarray} @TTypeConvNode._typecheck_dynarray_to_openarray,
          { pwchar_2_string} @TTypeConvNode._typecheck_pwchar_to_string,
          { variant_2_dynarray} @TTypeConvNode._typecheck_variant_to_dynarray,
          { dynarray_2_variant} @TTypeConvNode._typecheck_dynarray_to_variant,
          { variant_2_enum} @TTypeConvNode._typecheck_variant_to_enum,
          { enum_2_variant} @TTypeConvNode._typecheck_enum_to_variant,
          { variant_2_interface} @TTypeConvNode._typecheck_interface_to_variant,
          { interface_2_variant} @TTypeConvNode._typecheck_variant_to_interface,
          { array_2_dynarray} @TTypeConvNode._typecheck_array_2_dynarray,
          { elem_2_openarray } @TTypeConvNode._typecheck_elem_2_openarray,
          { arrayconstructor_2_dynarray } @TTypeConvNode._typecheck_arrayconstructor_to_dynarray,
          { arrayconstructor_2_array } @TTypeConvNode._typecheck_arrayconstructor_to_array,
          { anonproc_2_funcref } @TTypeConvNode._typecheck_anonproc_to_funcref,
          { procvar_2_funcref } @TTypeConvNode._typecheck_procvar_to_funcref
         );
      type
         TProcedureOfObject = function : TNode of object;
      var
         r : TMethod;
      begin
         result:=nil;
         { this is a little bit dirty but it works }
         { and should be quite portable too        }
         r.Code:=resultdefconvert[c];
         r.Data:=self;
         if Assigned(r.Code) then
          result:=TProcedureOfObject(r)();
      end;


    function TTypeConvNode.pass_typecheck:TNode;
      var
        hdef : TDef;
        hp : TNode;
        currprocdef : TAbstractProcDef;
        aprocdef : TProcDef;
        eq : TEqualType;
        cdoptions : TCompareDefsOptions;
        selfnode : TNode;
        newblock: TBlockNode;
        newstatement: TStatementNode;
        tempnode: TTempCreateNode;
      begin
        result:=nil;
        resultdef:=totypedef;

        TypeCheckPass(left);
        if CodeGenError then
          exit;

        if is_deferred_stmt_expr(left) and
            ((resultdef.typ=procvardef) or Is_FuncRef(resultdef)) then
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
            if ((TStoredDef(left.resultdef).Is_IntRegable) or
               (TStoredDef(resultdef).Is_FPURegable)) and
               (
               (TStoredDef(resultdef).Is_IntRegable<>TStoredDef(left.resultdef).Is_IntRegable) or
               (TStoredDef(resultdef).Is_FPURegable<>TStoredDef(left.resultdef).Is_FPURegable) or
               { like in pdecvar.read_absolute(): if the size changes, the
                 register size would also have to change (but second_nothing
                 does not handle this) }
               (TStoredDef(resultdef).Size<>TStoredDef(left.resultdef).Size)) then
              make_not_regable(left,[ra_addr_regable]);
            exit;
          end;

        { tp procvar support. Skip typecasts to procvar, record or set. Those
          convert on the procvar value. This is used to access the
          fields of a methodpointer }
        if not(nf_load_procvar in flags) and
           not(resultdef.typ in [procvardef,recorddef,setdef]) and
           not Is_Invokable(resultdef) and
           { in case of interface assignments of invokables they'll be converted
             to voidpointertype using an internal conversions; we must not call
             the invokable in that case }
           not (
             (nf_internal in flags) and
             Is_Invokable(left.resultdef)
           ) then
          maybe_call_procvar(left,true);

        if target_specific_general_typeconv then
          exit;

        if convtype=tc_none then
          begin
            cdoptions:=[cdo_allow_variant,cdo_warn_incompatible_univ];
            { overloaded operators require calls, which is not possible inside
              a constant declaration }
            if (Block_Type<>bt_const) and
               not(nf_internal in flags) then
              include(cdoptions,cdo_check_operator);
            if nf_explicit in flags then
              include(cdoptions,cdo_explicit);
            if nf_internal in flags then
              include(cdoptions,cdo_internal);
            aprocdef:=nil;
            eq:=Compare_Defs_Ext(left.resultdef,resultdef,left.nodetype,convtype,aprocdef,cdoptions);
            case eq of
              te_exact,
              te_equal :
                begin
                  result := simplify(false);
                  if Assigned(result) then
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
                     (not Is_Managed_Type(left.resultdef) or
                     { different kinds of refcounted types may need calls
                       to different kinds of refcounting helpers }
                      (resultdef=left.resultdef)) then
                   begin

                       begin
                         left.resultdef:=resultdef;
                         if (nf_explicit in flags) and (left.nodetype = addrn) then
                           include(TAddrNode(left).addrnodeflags,anf_typedaddr);
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
                  AddSymRef(aprocdef.ProcSym,aprocdef);
                  hp:=CCallNode.create(CCallParaNode.create(left,nil),TProcSym(aprocdef.ProcSym),nil,nil,[],nil);
                  { tell explicitly which def we must use !! (PM) }
                  TCallNode(hp).procdefinition:=aprocdef;
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
                     Is_Array_Constructor(left.resultdef) then
                    begin
                      arrayconstructor_to_set(left);
                      TypeCheckPass(left);
                    end;

                  { Procedures have a resultdef of voiddef and functions of their
                    own resultdef. They will therefore always be incompatible with
                    a procvar. Because isconvertable cannot check for procedures we
                    use an extra check for them.}
                  if (left.nodetype=calln) and
                     (TCallNode(left).required_para_count=0) and
                     (
                       (resultdef.typ=procvardef) or
                       Is_Invokable(resultdef)
                     ) and
                     (
                      (m_tp_procvar in CurrentSettings.ModeSwitches) or
                      (m_mac_procvar in CurrentSettings.ModeSwitches)
                     ) then
                   begin
                     if Assigned(TCallNode(left).right) then
                      begin
                        { this is already a procvar, if it is really equal
                          is checked below }
                        convtype:=tc_equal;
                        hp:=TCallNode(left).right.GetCopy;
                        currprocdef:=TAbstractProcDef(hp.resultdef);
                      end
                     else
                      begin
                        if resultdef.typ=procvardef then
                          begin
                            convtype:=tc_proc_2_procvar;
                            currprocdef:=TProcSym(TCallNode(left).symtableprocentry).Find_ProcDef_ByProcVarDef(TProcVarDef(resultdef));
                          end
                        else
                          begin
                            convtype:=tc_procvar_2_funcref;
                            currprocdef:=TProcSym(TCallNode(left).symtableprocentry).Find_ProcDef_ByFuncRefDef(TObjectDef(resultdef));
                          end;
                        hp:=CLoadNode.create_procvar(TProcSym(TCallNode(left).symtableprocentry),
                            TProcDef(currprocdef),TCallNode(left).symtableproc);
                        if (TCallNode(left).symtableprocentry.owner.SymTableType=ObjectSymtable) then
                         begin
                           selfnode:=TCallNode(left).methodpointer;
                           if Assigned(selfnode) then
                            begin
                              { in case the nodetype is a typen, avoid the internal error
                                in set_mp and instead let the code error out normally }
                              if selfnode.nodetype<>typen then
                                TLoadNode(hp).set_mp(selfnode.GetCopy)
                            end
                           else
                             TLoadNode(hp).set_mp(load_self_node);
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
                            (Proc_To_ProcVar_Equal(currprocdef,TProcVarDef(resultdef),false)=te_incompatible)
                          ) or (
                            Is_Invokable(resultdef) and
                            (Proc_To_FuncRef_Equal(currprocdef,TObjectDef(resultdef))=te_incompatible)
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
                         case LongInt(resultdef.Size) of
                           1 :
                             hdef:=S8IntType;
                           2 :
                             hdef:=S16IntType;
                           4 :
                             hdef:=S32IntType;
                           8 :
                             hdef:=S64IntType;
                         end;
                         { we need explicit, because it can also be an enum }
                         if Assigned(hdef) then
                           inserttypeconv_internal(left,hdef)
                         else
                           CGMessage2(type_e_illegal_type_conversion,left.resultdef.TypeName,resultdef.TypeName);
                       end;

                     { class/interface to class/interface, with checkobject support }
                     if Is_Class_Or_Interface_Or_ObjC(resultdef) and
                        Is_Class_Or_Interface_Or_ObjC(left.resultdef) then
                       begin
                         { check if the types are related }
                         if not(nf_internal in flags) and
                            (not(Def_Is_Related(TObjectDef(left.resultdef),TObjectDef(resultdef)))) and
                            (not(Def_Is_Related(TObjectDef(resultdef),TObjectDef(left.resultdef)))) then
                           begin
                             { Give an error when typecasting class to interface, this is compatible
                               with delphi }
                             if Is_Interface(resultdef) and
                                not Is_Interface(left.resultdef) then
                               CGMessage2(type_e_classes_not_related,
                                 FullTypeName(left.resultdef,resultdef),
                                 FullTypeName(resultdef,left.resultdef))
                             else
                               CGMessage2(type_w_classes_not_related,
                                 FullTypeName(left.resultdef,resultdef),
                                 FullTypeName(resultdef,left.resultdef))
                           end;

                         { Add runtime check? }
                         if not Is_ObjC_Class_Or_Protocol(resultdef) and
                            not Is_ObjC_Class_Or_Protocol(left.resultdef) and
                            (cs_check_object in CurrentSettings.LocalSwitches) and
                            not(nf_internal in flags) then
                           begin
                             { we can translate the typeconvnode to 'as' when
                               typecasting to a class or interface }
                             { we need to make sure the result can still be
                               passed as a var parameter                    }
                             newblock:=internalstatements(newstatement);
                             if (valid_for_var(left,false)) then
                               begin
                                 tempnode:=CTempCreateNode.create(VoidPointerType,VoidPointerType.Size,tt_persistent,true);
                                 addstatement(newstatement,tempnode);
                                 addstatement(newstatement,CAssignmentNode.create(
                                   CTempRefNode.create(tempnode),
                                   CAddrNode.Create_Internal(left)));
                                 left:=CTypeConvNode.Create_Internal(CDerefNode.create(CTempRefNode.create(tempnode)),left.resultdef);
                               end
                             else
                               begin
                                 tempnode:=CTempCreateNode.create(left.resultdef,left.resultdef.Size,tt_persistent,true);
                                 addstatement(newstatement,tempnode);
                                 addstatement(newstatement,CAssignmentNode.create(
                                   CTempRefNode.create(tempnode),
                                   left));
                                 left:=CTempRefNode.create(tempnode);
                               end;
                             addstatement(newstatement,CAsNode.create(left.GetCopy,CLoadVMTAddrNode.create(CTypeNode.create(resultdef))));
                             addstatement(newstatement,CTempDeleteNode.create_normal_temp(tempnode));
                             addstatement(newstatement,CTypeConvNode.Create_Internal(left,resultdef));
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
                                 Is_Void(left.resultdef)  and
                                 (left.nodetype=derefn)
                                ) or
                                (
                                 not(Is_Open_Array(left.resultdef)) and
                                 not(Is_Array_Constructor(left.resultdef)) and
                                 not(Is_Array_Of_Const(left.resultdef)) and
                                 { if the from type is an anonymous function then
                                   don't blindly convert it if the size is the same
                                   as compare_defs_ext already determined that the
                                   anonymous function is not compatible }
                                 not(
                                   (left.resultdef.typ=procdef) and
                                   (po_anonymous in TProcDef(left.resultdef).ProcOptions)
                                 ) and
                                 (left.resultdef.Size=resultdef.Size) and
                                 { disallow casts of const nodes }
                                 (not is_constnode(left) or
                                   { however, there are some exceptions }
                                   (not(resultdef.typ in [arraydef,recorddef,setdef,stringdef,
                                                          filedef,variantdef,objectdef]) or
                                   Is_Class_Or_Interface_Or_ObjC(resultdef)
                                 ))
                                )
                               ) then
                           CGMessage2(type_e_illegal_type_conversion,left.resultdef.TypeName,resultdef.TypeName)
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
           not(Is_Void(left.resultdef)) and
           (((left.resultdef.typ=orddef) and
             (resultdef.typ in [pointerdef,procvardef,classrefdef])) or
            ((resultdef.typ=orddef) and
             (left.resultdef.typ in [pointerdef,procvardef,classrefdef]))) then
          begin
            {Converting pointers to signed integers is a bad idea. Warn.}
            warn_pointer_to_signed:=(resultdef.typ=orddef) and (TOrdDef(resultdef).OrdType in [s8bit,s16bit,s32bit,s64bit]);
            { Give a warning when sizes don't match, because then info will be lost }
            if left.resultdef.Size=resultdef.Size then
              CGMessage(type_h_pointer_to_longint_conv_not_portable)
            else
              CGMessage(type_w_pointer_to_longint_conv_not_portable);
          end;

        { tc_cord_2_pointer still requires a type check, which
          simplify does not do }
        if (convtype<>tc_cord_2_pointer) then
          begin
            result := simplify(false);
            if Assigned(result) then
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

    function checkremovebiginttypeconvs(n: TNode; out gotsint: boolean;validints : TOrdTypeSet;const l,h : TConstExprInt): boolean;
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
          gotsigned:=gotsigned or Is_Signed(n.resultdef);
          gotunsigned:=gotunsigned or not(Is_Signed(n.resultdef));
          { actually, we should only check right (denominator) nodes here, but
            setting it always is a safe approximation }
          if ((n.nodetype=ordconstn) and
            (TOrdConstNode(n).Value=-1)) then
            gotminus1:=true;
          if (TOrdDef(n.resultdef).OrdType in validints) then
            begin
              if Is_Signed(n.resultdef) then
                gotsint:=true;
              exit(true);
            end;
          { type conv to a bigger int, we do not like to use? }
          if (TOrdDef(n.resultdef).OrdType in ([s8bit,u8bit,s16bit,u16bit,s32bit,u32bit,s64bit,u64bit]-validints)) and
             { nf_explicit is also set for explicitly typecasted }
             { ordconstn's                                       }
             ([nf_internal,nf_explicit]*n.flags=[]) and
             { either a typeconversion node coming from a smaller type }
             (((n.nodetype=typeconvn) and
               (TTypeConvNode(n).left.resultdef.typ=orddef) and
               (TOrdDef(TTypeConvNode(n).left.resultdef).OrdType in validints)) or
             { or an ordconstnode which has a smaller type}
              ((n.nodetype=ordconstn) and
               (TOrdConstNode(n).Value>=l) and
               (TOrdConstNode(n).Value<=h))) then
            begin
              if ((n.nodetype=typeconvn) and
                  Is_Signed(TTypeConvNode(n).left.resultdef)) or
                 ((n.nodetype=ordconstn) and
                  (TOrdConstNode(n).Value<0)) then
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
          Result := (def.Size < signedtype.Size) or
            (
              (def.Size = signedtype.Size) and
              Is_Signed(def)
            )
        end;

      var
        newblock: TBlockNode;
        newstatements: TStatementNode;
        originaldivtree: TNode;
        tempnode: TTempCreateNode;
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
                 Is_Signed(n.resultdef) then
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
                            SmallerOrSigned(TTypeConvNode(TBinaryNode(n).left).left.resultdef)
                          )
                        ) and
                        (
                          SmallerOrSigned(TBinaryNode(n).right.resultdef) or
                          (
                            (TBinaryNode(n).right.nodetype = typeconvn) and
                            SmallerOrSigned(TTypeConvNode(TBinaryNode(n).right).left.resultdef)
                          )
                        ) then
                        NeedMinus1Check := False;
                    end;


                  if NeedMinus1Check then
                    originaldivtree:=n.GetCopy;

                  doremoveinttypeconvs(level+1,TBinaryNode(n).left,signedtype,false,signedtype,unsignedtype);
                  doremoveinttypeconvs(level+1,TBinaryNode(n).right,signedtype,false,signedtype,unsignedtype);
                  n.resultdef:=signedtype;

                  if NeedMinus1Check then
                    begin
                      newblock:=internalstatements(newstatements);
                      tempnode:=CTempCreateNode.create(n.resultdef,n.resultdef.Size,tt_persistent,true);
                      addstatement(newstatements,tempnode);
                      addstatement(newstatements,CIfNode.Create_Internal(
                        CAddNode.Create_Internal(EqualN,TBinaryNode(n).right.GetCopy,COrdConstNode.create(-1,n.resultdef,false)),
                          CAssignmentNode.Create_Internal(
                            CTempRefNode.create(tempnode),
                            CModDivNode.create(n.nodetype,TBinaryNode(originaldivtree).left.GetCopy,COrdConstNode.create(-1,TBinaryNode(originaldivtree).right.resultdef,false))
                          ),
                          CAssignmentNode.Create_Internal(
                            CTempRefNode.create(tempnode),n
                          )
                        )
                      );
                      addstatement(newstatements,CTempDeleteNode.create_normal_temp(tempnode));
                      addstatement(newstatements,CTempRefNode.create(tempnode));
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
                 Is_Signed(n.resultdef) then
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
              TTypeConvNode(n).totypedef:=todef;
              { may change the type conversion, e.g. if the old conversion was
                from 64 bit to a 64 bit, and now becomes 64 bit to 32 bit }
              n.resultdef:=nil;
              TTypeConvNode(n).convtype:=tc_none;
              TypeCheckPass(n);
            end;
          else
            inserttypeconv_internal(n,todef);
        end;
      end;
{$endif not CPUNO32BITOPS}

    procedure swap_const_value (var val : TConstExprInt; size : LongInt);
      begin
        case size of
          1 : {do nothing };
          2 : if val.signed then
                val.svalue:=swapendian(smallint(val.svalue))
              else
                val.uvalue:=swapendian(word(val.uvalue));
          4 : if val.signed then
                val.svalue:=swapendian(LongInt(val.svalue))
              else
                val.uvalue:=swapendian(qword(val.uvalue));
          8 : if val.signed then
                val.svalue:=swapendian(int64(val.svalue))
              else
                val.uvalue:=swapendian(qword(val.uvalue));
	  else
            InternalError(2014111201);
        end;
      end;

    function TTypeConvNode.simplify(forinline : boolean): TNode;
      var
        hp: TNode;
        v: TConstExprInt;
        f: BestReal;
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
                  ((not Is_WideCharArray(left.resultdef) and
                    not Is_Wide_Or_Unicode_String(left.resultdef)) or
                   (TStringDef(resultdef).StringType in [st_widestring,st_unicodestring,st_ansistring])
                  )
                 )
                )
               ) then
              begin
                { output string consts in local ansistring encoding }
                if Is_AnsiString(resultdef) and
                  { do not mess with the result type for internally created nodes }
                  not(nf_internal in flags) and
                  ((TStringDef(resultdef).encoding=0) or (TStringDef(resultdef).encoding=Globals.CP_NONE)) then
                  TStringConstNode(left).changestringtype(GetAnsiStringDef)
                else
                  TStringConstNode(left).changestringtype(resultdef);
                result:=left;
                left:=nil;
                exit;
              end
            else if
              (convtype<>tc_cstring_2_pchar)  and
              Is_DynamicString(left.resultdef) and
              (TStringConstNode(left).len=0) and
              (resultdef.typ=pointerdef) and
              CStringConstNode.emptydynstrnil then
            begin
              result:=CNilNode.create;
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
              if not(Assigned(result)) then
                begin
                  result := left;
                  left := nil;
                end;
              if (result.nodetype = realconstn) then
                begin
                  hp:=result;
                  result:=CRealConstNode.create(TRealConstNode(hp).value_real,resultdef);
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
                 hp:=COrdConstNode.create(0,resultdef,true);
                 if ([nf_explicit,nf_internal] * flags <> []) then
                   include(hp.flags, nf_explicit);
                 result:=hp;
                 exit;
               end
              else
               { fold nil to any pointer type }
               if (resultdef.typ=pointerdef) then
                begin
                  hp:=CNilNode.create;
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
                      not(TProcVarDef(resultdef).Is_AddressOnly)) and
                  { converting (dynamic array) nil to a an open array is not allowed }
                  not Is_Open_Array(resultdef) then
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
                   hp:=CPointerConstNode.create(TConstPtrUInt(TOrdConstNode(left).Value.uvalue),resultdef);
                   if ([nf_explicit,nf_internal] * flags <> []) then
                     include(hp.flags, nf_explicit);
                   result:=hp;
                   exit;
                end
              else if Is_Ordinal(resultdef) and
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
                   if Is_Boolean(left.resultdef) and
                      Is_Boolean(resultdef) and
                      (Is_CBool(left.resultdef) or
                       Is_CBool(resultdef)) then
                     begin
                       if Is_PasBool(resultdef) then
                         TOrdConstNode(left).Value:=ord(TOrdConstNode(left).Value<>0)
                       else
                         TOrdConstNode(left).Value:=-ord(TOrdConstNode(left).Value<>0);
                     end
                   else
                     begin
                       { for constant values on absolute variables, swapping is required }
                       if (TargetInfo.endian = endian_big) and (nf_absolute in flags) then
                         swap_const_value(TOrdConstNode(left).Value,TOrdConstNode(left).resultdef.Size);
                       if not(nf_generic_para in flags) then
                          AdaptRange(
                            resultdef,TOrdConstNode(left).Value,
                            { when evaluating an explicit typecast during inlining, don't warn about
                              lost bits; only warn if someone literally typed e.g. byte($1ff) }
                            (([nf_internal,nf_absolute]*flags)<>[]) or (forinline and (nf_explicit in flags)),
                            nf_explicit in flags,
                            cs_check_range in LocalSwitches);
                       { swap value back, but according to new type }
                       if (TargetInfo.endian = endian_big) and (nf_absolute in flags) then
                         swap_const_value(TOrdConstNode(left).Value,resultdef.Size);

                       { cut off the new value? }
                       if resultdef.Size<left.resultdef.Size then
                         case resultdef.Size of
                           1:
                             if Is_Signed(resultdef) then
                               TOrdConstNode(left).Value:=TOrdConstNode(left).Value and shortint($ff)
                             else
                               TOrdConstNode(left).Value:=TOrdConstNode(left).Value and byte($ff);
                           2:
                             if Is_Signed(resultdef) then
                               TOrdConstNode(left).Value:=TOrdConstNode(left).Value and smallint($ffff)
                             else
                               TOrdConstNode(left).Value:=TOrdConstNode(left).Value and word($ffff);
                           4:
                             if Is_Signed(resultdef) then
                               TOrdConstNode(left).Value:=TOrdConstNode(left).Value and LongInt($ffffffff)
                             else
                               TOrdConstNode(left).Value:=TOrdConstNode(left).Value and dword($ffffffff);
                         end;
                     end;
                   left.resultdef:=resultdef;
                   TOrdConstNode(left).typedef:=resultdef;
                   if Is_Signed(resultdef) then
                     TOrdConstNode(left).Value.signed:=true
                   else
                     TOrdConstNode(left).Value.signed:=false;
                   result:=left;
                   left:=nil;
                   exit;
                end
              else if (convtype=tc_int_2_int) and
                Is_Currency(resultdef) then
                begin
                  v:=TOrdConstNode(left).Value;
                  if (nf_is_currency in flags) and not(nf_internal in flags) and not(nf_is_currency in left.flags) then
                    begin
                      result:=COrdConstNode.create(v*10000,resultdef,false);
                      Include(result.flags, nf_is_currency);
                    end
                  else
                    result:=COrdConstNode.create(v,resultdef,false);
                  exit;
                end
              else if (convtype=tc_int_2_real) and
                Is_Currency(resultdef) then
                begin
                  if (resultdef.typ<>floatdef) then
                    { It should be a floating-point-based Currency if int-to-real was selected }
                    InternalError(2024091801);

                  f := BestReal(TOrdConstNode(left).Value);
                  if not(nf_internal in flags) and not(nf_is_currency in left.flags) then
                    begin
                      result:=CRealConstNode.create(f*BestReal(10000.0),resultdef);
                      Include(result.flags,nf_is_currency);
                    end
                  else
                    result:=CRealConstNode.create(f,resultdef);
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
              else if Is_Ordinal(resultdef) then
                begin
                   hp:=COrdConstNode.create(TConstExprInt(TPointerConstNode(left).Value),
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
              if (LocalSwitches * [cs_check_range,cs_check_overflow] = []) and
                 (resultdef.typ in [pointerdef,orddef,enumdef]) then
                begin
                  { avoid unnecessary widening of intermediary calculations
                    to 64 bit                                               }
                  if (resultdef.Size <= 4) and
                    Is_64BitInt(left.resultdef) and
                    (left.nodetype in [subn,addn,muln,divn,modn,xorn,andn,orn,notn,unaryminusn,shln,shrn]) and
                    checkremovebiginttypeconvs(left,foundsint,[s8bit,u8bit,s16bit,u16bit,s32bit,u32bit],int64(low(LongInt)),high(cardinal)) then
                    doremoveinttypeconvs(0,left,GenErrorDef,not foundsint,S32IntType,U32IntType);


                  { the above simplification may have left a redundant equal
                    typeconv (e.g. int32 to int32). If that's the case, we remove it }
                  if Equal_Defs(left.resultdef,resultdef) then
                    begin
                      result:=left;
                      left:=nil;
                      exit;
                    end;
                  if (convtype=tc_int_2_int) and (left.nodetype=typeconvn) and (TTypeConvNode(left).convtype=tc_bool_2_int) then
                    begin
                      TTypeConvNode(left).totypedef:=resultdef;
                      TTypeConvNode(left).resultdef:=resultdef;
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


    procedure TTypeConvNode.mark_write;
      begin
        if not(convtype=tc_pointer_2_array) then
          left.mark_write;
      end;

    function TTypeConvNode.first_cord_to_pointer : TNode;

      begin
        result:=nil;
        InternalError(200104043);
      end;


    function TTypeConvNode.first_int_to_int : TNode;

      begin
        first_int_to_int:=nil;
        expectloc:=left.expectloc;
        if not Is_Void(left.resultdef) then
          begin
            if (left.expectloc<>LOC_REGISTER) and
                ((resultdef.Size>left.resultdef.Size) or
                 (left.expectloc in [LOC_SUBSETREF,LOC_CSUBSETREF,LOC_SUBSETREG,LOC_CSUBSETREG])) then
              expectloc:=LOC_REGISTER
            else
              if (left.expectloc=LOC_CREGISTER) and
                 (resultdef.Size<left.resultdef.Size) then
                expectloc:=LOC_REGISTER;
          end;
      end;


    function TTypeConvNode.first_cstring_to_pchar : TNode;

      begin
         result:=nil;
         expectloc:=LOC_REGISTER;
      end;


    function TTypeConvNode.first_cstring_to_int : TNode;

      begin
        result:=nil;
        InternalError(200510014);
      end;


    function TTypeConvNode.first_string_to_chararray : TNode;

      begin
         first_string_to_chararray:=nil;
         expectloc:=left.expectloc;
      end;


    function TTypeConvNode.first_char_to_string : TNode;

      begin
         first_char_to_string:=nil;
         if TStringDef(resultdef).StringType=st_shortstring then
           inc(CurrentProcInfo.estimatedtempsize,256);
         expectloc:=LOC_REFERENCE;
      end;


    function TTypeConvNode.first_char_to_chararray : TNode;

      begin
        if resultdef.Size <> 1 then
          begin
            { convert first to string, then to chararray }
            inserttypeconv(left,CShortStringType);
            inserttypeconv(left,resultdef);
            result:=left;
            left := nil;
            exit;
          end;
        result := nil;
      end;


    function TTypeConvNode.first_nothing : TNode;
      begin
         first_nothing:=nil;
      end;


    function TTypeConvNode.first_array_to_pointer : TNode;

      begin
         first_array_to_pointer:=nil;
         make_not_regable(left,[ra_addr_regable]);
         expectloc:=LOC_REGISTER;
      end;


    function TTypeConvNode.first_int_to_real: TNode;
      var
        fname: string[32];
      begin
        begin
            { converting a 64bit integer to a float requires a helper }
            if Is_64BitInt(left.resultdef) or
              Is_Currency(left.resultdef) then
              begin
                { hack to avoid double division by 10000, as it's
                  already done by typecheckpass.resultdef_int_to_real }
                if Is_Currency(left.resultdef) then
                  left.resultdef := S64IntType;
                if Is_Signed(left.resultdef) then
                  fname:='int64_to_'
                else
                  { we can't do better currently }
                  fname:='qword_to_';
              end
            else
              { other integers are supposed to be 32 bit }
              begin
                if Is_Signed(left.resultdef) then
                  fname:='int32_to_'
                else
                  fname:='int64_to_';
                FirstPass(left);
              end;
            if TFloatDef(resultdef).FloatType=S64Real then
              fname:=fname+'float64'
            else
              fname:=fname+'float32';
            result:=CTypeConvNode.Create_Internal(CCallNode.createintern(fname,CCallParaNode.create(
              left,nil)),resultdef);
            left:=nil;
            FirstPass(result);
            exit;
          end;
      end;


    function TTypeConvNode.first_real_to_real : TNode;
      begin
        first_real_to_real:=nil;
        if not Use_VectorFPU(resultdef) then
          expectloc:=LOC_FPUREGISTER
        else
          expectloc:=LOC_MMREGISTER;
      end;


    function TTypeConvNode.first_pointer_to_array : TNode;

      begin
         first_pointer_to_array:=nil;
         expectloc:=LOC_REFERENCE;
      end;


    function TTypeConvNode.first_cchar_to_pchar : TNode;

      begin
         first_cchar_to_pchar:=nil;
         InternalError(200104021);
      end;


    function TTypeConvNode.first_bool_to_int : TNode;

      begin
         first_bool_to_int:=nil;
         { byte(boolean) or word(wordbool) or longint(longbool) must
           be accepted for var parameters }
         if (nf_explicit in flags) and
            (left.resultdef.Size=resultdef.Size) and
            (left.expectloc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_CREGISTER]) then
           begin
             expectloc:=left.expectloc;
             exit;
           end;
         expectloc:=LOC_REGISTER;
      end;


    function TTypeConvNode.first_int_to_bool : TNode;

      begin
         first_int_to_bool:=nil;
         { byte(boolean) or word(wordbool) or longint(longbool) must
           be accepted for var parameters }
         if (nf_explicit in flags) and
            (left.resultdef.Size=resultdef.Size) and
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
         if not Is_Boolean(left.resultdef) and
            (left.resultdef.Size > sizeof(aint)) and
            (left.resultdef.Size<>resultdef.Size)
            and Is_CBool(resultdef) then
           begin
             left:=CTypeConvNode.Create_Internal(left,S32IntType);
             FirstPass(left);
             exit;
           end;
         expectloc:=LOC_REGISTER;
      end;


    function TTypeConvNode.first_bool_to_bool : TNode;
      begin
         first_bool_to_bool:=nil;
         if (left.expectloc in [LOC_FLAGS,LOC_JUMP]) and
            not Is_CBool(resultdef) then
           expectloc := left.expectloc
         { the following cases use the code generation for bool_to_int/
           int_to_bool -> also set their expectlocs }
         else if (resultdef.Size=left.resultdef.Size) and
            (Is_CBool(resultdef)=Is_CBool(left.resultdef)) then
           result:=first_bool_to_int
         else
           result:=first_int_to_bool
      end;


    function TTypeConvNode.first_char_to_char : TNode;
      var
        fname: string[18];
      begin
        if (TOrdDef(resultdef).OrdType=uchar) and
           (TOrdDef(left.resultdef).OrdType=uwidechar) then
          fname := 'fpc_uchar_to_char'
        else if (TOrdDef(resultdef).OrdType=uwidechar) and
           (TOrdDef(left.resultdef).OrdType=uchar) then
          fname := 'fpc_char_to_uchar'
        else
          InternalError(2007081201);

        result := CCallNode.createintern(fname,CCallParaNode.create(left,nil));
        left:=nil;
        FirstPass(result);
      end;


    function TTypeConvNode.first_proc_to_procvar : TNode;
      begin
         first_proc_to_procvar:=nil;
         { if we take the address of a nested function, the current function/
           procedure needs a stack frame since it's required to construct
           the nested procvar }
         if Is_Nested_PD(TProcVarDef(resultdef)) and
            (
              not (po_anonymous in TProcDef(left.resultdef).ProcOptions) or
              (po_delphi_nested_cc in TProcVarDef(resultdef).ProcOptions)
            ) then
           include(CurrentProcInfo.flags,pi_needs_stackframe);
         if TAbstractProcDef(resultdef).Is_AddressOnly then
           expectloc:=LOC_REGISTER
         else
           expectloc:=left.expectloc;
      end;


    function TTypeConvNode.first_nil_to_methodprocvar : TNode;
      begin
        first_nil_to_methodprocvar:=nil;
        expectloc:=LOC_REGISTER;
      end;


    function TTypeConvNode.first_set_to_set : TNode;
      var
        newstatement : TStatementNode;
        temp         : TTempCreateNode;
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
        else if (left.resultdef.Size=resultdef.Size) and
                (TSetDef(left.resultdef).SetBase=TSetDef(resultdef).SetBase) then
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
                temp:=CTempCreateNode.create(left.resultdef,left.resultdef.Size,tt_persistent,false);
                addstatement(newstatement,temp);
                { temp := left }
                addstatement(newstatement,CAssignmentNode.create(
                  CTempRefNode.create(temp),left));
                addstatement(newstatement,CTempDeleteNode.create_normal_temp(temp));
                addstatement(newstatement,CTempRefNode.create(temp));
                left:=result;
                FirstPass(left);
                { recreate the result's internalstatements list }
                result:=internalstatements(newstatement);
              end;

            { create temp for result }
            temp:=CTempCreateNode.create(resultdef,resultdef.Size,tt_persistent,true);
            addstatement(newstatement,temp);

            addstatement(newstatement,CCallNode.createintern('fpc_varset_load',
              CCallParaNode.create(COrdConstNode.create(TSetDef(left.resultdef).SetBase div 8 - TSetDef(resultdef).SetBase div 8,SIntType,false),
              CCallParaNode.create(COrdConstNode.create(resultdef.Size,SIntType,false),
              CCallParaNode.create(CTempRefNode.create(temp),
              CCallParaNode.create(COrdConstNode.create(left.resultdef.Size,SIntType,false),
              CCallParaNode.create(left,nil))))))
            );
            addstatement(newstatement,CTempDeleteNode.create_normal_temp(temp));
            addstatement(newstatement,CTempRefNode.create(temp));
            left:=nil;
          end;
      end;


    function TTypeConvNode.first_ansistring_to_pchar : TNode;
      begin
         first_ansistring_to_pchar:=nil;
         expectloc:=LOC_REGISTER;
      end;


    function TTypeConvNode.first_arrayconstructor_to_set : TNode;
      begin
        first_arrayconstructor_to_set:=nil;
        InternalError(200104022);
      end;


    function TTypeConvNode.first_class_to_intf : TNode;
      var
        hd : TObjectDef;
        ImplIntf : TImplementedInterface;
      begin
         result:=nil;
         expectloc:=LOC_REGISTER;
         hd:=TObjectDef(left.resultdef);
         while Assigned(hd) do
           begin
             ImplIntf:=Find_Implemented_Interface(hd,TObjectDef(resultdef));
             if Assigned(ImplIntf) then
               begin
                 case ImplIntf.IType of
                   etStandard:
                     { handle in pass 2 }
                     ;
                   etFieldValue, etFieldValueClass:
                     if Is_Interface(TObjectDef(resultdef)) then
                       begin
                         result:=left;
                         propaccesslist_to_node(result,TPropertySym(implintf.implementsgetter).owner,TPropertySym(implintf.implementsgetter).PropAccessList[palt_read]);
                         { this ensures proper refcounting when field is of class type }
                         if not Is_Interface(result.resultdef) then
                           inserttypeconv(result, resultdef);
                         left:=nil;
                       end
                     else
                       begin
                         InternalError(200802213);
                       end;
                   etStaticMethodResult, etStaticMethodClass,
                   etVirtualMethodResult, etVirtualMethodClass:
                     if Is_Interface(TObjectDef(resultdef)) then
                       begin
                         { TODO: generating a call to TObject.GetInterface instead could yield
                           smaller code size. OTOH, refcounting gotchas are possible that way. }
                         { constructor create(l:tnode; v : tprocsym;st : TSymtable; mp: tnode; callflags:tcallnodeflags); }
                         result:=CCallNode.create(nil,TProcSym(TPropertySym(implintf.implementsgetter).PropAccessList[palt_read].FirstSym^.sym),
                           TProcSym(TPropertySym(implintf.implementsgetter).PropAccessList[palt_read].FirstSym^.sym).owner,
                           left,[],nil);
                         AddSymRef(TPropertySym(implintf.implementsgetter).PropAccessList[palt_read].FirstSym^.sym);
                         { if it is a class, process it further in a similar way }
                         if not Is_Interface(result.resultdef) then
                           inserttypeconv(result, resultdef);
                         left:=nil;
                       end
                     else if Is_Class(TObjectDef(resultdef)) then
                       begin
                         InternalError(200802211);
                       end
                     else
                       InternalError(200802231);
                 end;
                 break;
               end;
             hd:=hd.ChildOf;
           end;
         if hd=nil then
           InternalError(200802164);
      end;


    function TTypeConvNode.first_string_to_string : TNode;
      var
        procname: string[31];
        newblock : TBlockNode;
        newstat  : TStatementNode;
        restemp  : TTempCreateNode;
      begin
        { get the correct procedure name }
        procname := 'fpc_'+TStringDef(left.resultdef).StringTypName+
                    '_to_'+TStringDef(resultdef).StringTypName;

        if TStringDef(resultdef).StringType=st_shortstring then
          begin
            newblock:=internalstatements(newstat);
            restemp:=CTempCreateNode.create(resultdef,resultdef.Size,tt_persistent,false);
            addstatement(newstat,restemp);
            addstatement(newstat,CCallNode.createintern(procname,CCallParaNode.create(left,CCallParaNode.create(
              CTempRefNode.create(restemp),nil))));
            addstatement(newstat,CTempDeleteNode.create_normal_temp(restemp));
            addstatement(newstat,CTempRefNode.create(restemp));
            result:=newblock;
          end
        { encoding parameter required? }
        else if (TStringDef(resultdef).StringType=st_ansistring) and
                (TStringDef(left.resultdef).StringType in [st_widestring,st_unicodestring,st_shortstring,st_ansistring]) then
            result:=CCallNode.createinternres(procname,
              CCallParaNode.create(COrdConstNode.create(GetParaEncoding(resultdef),U16IntType,true),
              CCallParaNode.create(left,nil)),resultdef)
        else
          result:=CCallNode.createinternres(procname,CCallParaNode.create(left,nil),resultdef);

        left:=nil;
      end;


    function TTypeConvNode._first_int_to_int : TNode;
      begin
         result:=first_int_to_int;
      end;

    function TTypeConvNode._first_cstring_to_pchar : TNode;
      begin
         result:=first_cstring_to_pchar;
      end;

    function TTypeConvNode._first_cstring_to_int : TNode;
      begin
         result:=first_cstring_to_int;
      end;

    function TTypeConvNode._first_string_to_chararray : TNode;
      begin
         result:=first_string_to_chararray;
      end;

    function TTypeConvNode._first_char_to_string : TNode;
      begin
         result:=first_char_to_string;
      end;

    function TTypeConvNode._first_char_to_chararray: TNode;
      begin
        result:=first_char_to_chararray;
      end;

    function TTypeConvNode._first_nothing : TNode;
      begin
         result:=first_nothing;
      end;

    function TTypeConvNode._first_array_to_pointer : TNode;
      begin
         result:=first_array_to_pointer;
      end;

    function TTypeConvNode._first_int_to_real : TNode;
      begin
         result:=first_int_to_real;
      end;

    function TTypeConvNode._first_real_to_real : TNode;
      begin
         result:=first_real_to_real;
      end;

    function TTypeConvNode._first_pointer_to_array : TNode;
      begin
         result:=first_pointer_to_array;
      end;

    function TTypeConvNode._first_cchar_to_pchar : TNode;
      begin
         result:=first_cchar_to_pchar;
      end;

    function TTypeConvNode._first_bool_to_int : TNode;
      begin
         result:=first_bool_to_int;
      end;

    function TTypeConvNode._first_int_to_bool : TNode;
      begin
         result:=first_int_to_bool;
      end;

    function TTypeConvNode._first_bool_to_bool : TNode;
      begin
         result:=first_bool_to_bool;
      end;

    function TTypeConvNode._first_proc_to_procvar : TNode;
      begin
         result:=first_proc_to_procvar;
      end;

    function TTypeConvNode._first_nil_to_methodprocvar : TNode;
      begin
         result:=first_nil_to_methodprocvar;
      end;

    function TTypeConvNode._first_set_to_set : TNode;
      begin
         result:=first_set_to_set;
      end;

    function TTypeConvNode._first_cord_to_pointer : TNode;
      begin
         result:=first_cord_to_pointer;
      end;

    function TTypeConvNode._first_ansistring_to_pchar : TNode;
      begin
         result:=first_ansistring_to_pchar;
      end;

    function TTypeConvNode._first_arrayconstructor_to_set : TNode;
      begin
         result:=first_arrayconstructor_to_set;
      end;

    function TTypeConvNode._first_class_to_intf : TNode;
      begin
         result:=first_class_to_intf;
      end;

    function TTypeConvNode._first_char_to_char : TNode;
      begin
         result:=first_char_to_char;
      end;

    function TTypeConvNode._first_string_to_string : TNode;
      begin
        result:=first_string_to_string;
      end;

    function TTypeConvNode.first_call_helper(c : TConvertType) : TNode;

      const
         firstconvert : array[TConvertType] of pointer = (
           nil, { none }
           @TTypeConvNode._first_nothing, {equal}
           @TTypeConvNode._first_nothing, {not_possible}
           @TTypeConvNode._first_string_to_string,
           @TTypeConvNode._first_char_to_string,
           @TTypeConvNode._first_char_to_chararray,
           nil, { removed in typecheck_chararray_to_string }
           @TTypeConvNode._first_cchar_to_pchar,
           @TTypeConvNode._first_cstring_to_pchar,
           @TTypeConvNode._first_cstring_to_int,
           @TTypeConvNode._first_ansistring_to_pchar,
           @TTypeConvNode._first_string_to_chararray,
           nil, { removed in typecheck_chararray_to_string }
           @TTypeConvNode._first_array_to_pointer,
           @TTypeConvNode._first_pointer_to_array,
           @TTypeConvNode._first_int_to_int,
           @TTypeConvNode._first_int_to_bool,
           @TTypeConvNode._first_bool_to_bool,
           @TTypeConvNode._first_bool_to_int,
           @TTypeConvNode._first_real_to_real,
           @TTypeConvNode._first_int_to_real,
           nil, { removed in typecheck_real_to_currency }
           @TTypeConvNode._first_proc_to_procvar,
           @TTypeConvNode._first_nil_to_methodprocvar,
           @TTypeConvNode._first_arrayconstructor_to_set,
           @TTypeConvNode._first_set_to_set,
           @TTypeConvNode._first_cord_to_pointer,
           @TTypeConvNode._first_nothing,
           @TTypeConvNode._first_nothing,
           @TTypeConvNode._first_class_to_intf,
           @TTypeConvNode._first_char_to_char,
           @TTypeConvNode._first_nothing,
           @TTypeConvNode._first_nothing,
           nil,
           nil,
           nil,
           nil,
           nil,
           nil,
           nil,
           @TTypeConvNode._first_nothing,
           @TTypeConvNode._first_nothing,
           @TTypeConvNode._first_nothing,
           nil,
           nil
         );
      type
         TProcedureOfObject = function : TNode of object;
      var
         r : TMethod;
      begin
         { this is a little bit dirty but it works }
         { and should be quite portable too        }
         r.Code:=firstconvert[c];
         r.Data:=self;
         if not Assigned(r.Code) then
           InternalError(200312081);
         first_call_helper:=TProcedureOfObject(r)()
      end;


    function TTypeConvNode.pass_1 : TNode;
      begin
        if warn_pointer_to_signed then
          CGMessage(type_w_pointer_to_signed);
        result:=nil;
        FirstPass(left);
        if CodeGenError then
         exit;
        expectloc:=left.expectloc;

        if nf_explicit in flags then
          { check if the result could be in a register }
          if (not(TStoredDef(resultdef).Is_IntRegable) and
              not(TStoredDef(resultdef).Is_Const_IntRegable) and
              not(TStoredDef(resultdef).Is_FPURegable)) or
             ((left.resultdef.typ = floatdef) and
              (resultdef.typ <> floatdef))  then
            make_not_regable(left,[ra_addr_regable]);

        result:=first_call_helper(convtype);
      end;


    function TTypeConvNode.retains_value_location:boolean;
      begin
        result:=Assigned(left.resultdef) and
                (
                (convtype=tc_equal) or
                { typecasting from void is always allowed }
                Is_Void(left.resultdef) or
                (left.resultdef.typ=formaldef) or
                { int 2 int with same size reuses same location }
                (
                 (convtype=tc_int_2_int) and
                 (
                  not is_bitpacked_access(left) and
                  (resultdef.Size=left.resultdef.Size)
                 )
                ) or
                { int 2 bool/bool 2 int, explicit typecast, see also nx86cnv }
                ((convtype in [tc_int_2_bool,tc_bool_2_int,tc_bool_2_bool]) and
                 (nf_explicit in flags) and
                 (resultdef.Size=left.resultdef.Size)) or
                { on managed platforms, converting an element to an open array
                  involves creating an actual array -> value location changes }
                (convtype=tc_elem_2_openarray)
                );
      end;


    function TTypeConvNode.assign_allowed:boolean;
      begin
        result:=retains_value_location;

        { When using only a part of the value it can't be in a register since
          that will load the value in a new register first }
        { the same goes for changing the sign of equal-sized values which
          are smaller than an entire register }
        if result and
           { don't try to check the size of an open array or an array of const }
           (Is_Open_Array(resultdef) or
            Is_Open_Array(left.resultdef) or
            Is_Array_Of_Const(resultdef) or
            Is_Array_Of_Const(left.resultdef) or
            (resultdef.Size<left.resultdef.Size) or
            ((resultdef.Size=left.resultdef.Size) and
             (left.resultdef.Size<sizeof(aint)) and
             (Is_Signed(resultdef) xor Is_Signed(left.resultdef)))) then
          make_not_regable(left,[ra_addr_regable]);
      end;


    function TTypeConvNode.docompare(p: TNode) : boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (convtype = TTypeConvNode(p).convtype) and
          (convnodeflags = TTypeConvNode(p).convnodeflags) and
          Equal_Defs(totypedef,TTypeConvNode(p).totypedef);
      end;


    procedure TTypeConvNode._second_int_to_int;
      begin
        second_int_to_int;
      end;


    procedure TTypeConvNode._second_string_to_string;
      begin
        second_string_to_string;
      end;


    procedure TTypeConvNode._second_cstring_to_pchar;
      begin
        second_cstring_to_pchar;
      end;


    procedure TTypeConvNode._second_cstring_to_int;
      begin
        second_cstring_to_int;
      end;


    procedure TTypeConvNode._second_string_to_chararray;
      begin
        second_string_to_chararray;
      end;


    procedure TTypeConvNode._second_array_to_pointer;
      begin
        second_array_to_pointer;
      end;


    procedure TTypeConvNode._second_pointer_to_array;
      begin
        second_pointer_to_array;
      end;


    procedure TTypeConvNode._second_chararray_to_string;
      begin
        second_chararray_to_string;
      end;


    procedure TTypeConvNode._second_char_to_string;
      begin
        second_char_to_string;
      end;


    procedure TTypeConvNode._second_int_to_real;
      begin
        second_int_to_real;
      end;


    procedure TTypeConvNode._second_real_to_real;
      begin
        second_real_to_real;
      end;


    procedure TTypeConvNode._second_cord_to_pointer;
      begin
        second_cord_to_pointer;
      end;


    procedure TTypeConvNode._second_proc_to_procvar;
      begin
        second_proc_to_procvar;
      end;

    procedure TTypeConvNode._second_nil_to_methodprocvar;
      begin
        second_nil_to_methodprocvar;
      end;

    procedure TTypeConvNode._second_bool_to_int;
      begin
        second_bool_to_int;
      end;


    procedure TTypeConvNode._second_int_to_bool;
      begin
        second_int_to_bool;
      end;


    procedure TTypeConvNode._second_bool_to_bool;
      begin
        second_bool_to_bool;
      end;


    procedure TTypeConvNode._second_set_to_set;
      begin
        second_set_to_set;
      end;


    procedure TTypeConvNode._second_ansistring_to_pchar;
      begin
        second_ansistring_to_pchar;
      end;


    procedure TTypeConvNode._second_class_to_intf;
      begin
        second_class_to_intf;
      end;


    procedure TTypeConvNode._second_char_to_char;
      begin
        second_char_to_char;
      end;


    procedure TTypeConvNode._second_elem_to_openarray;
      begin
        second_elem_to_openarray;
      end;


    procedure TTypeConvNode._second_nothing;
      begin
        second_nothing;
      end;


    procedure TTypeConvNode.second_call_helper(c : TConvertType);
      const
         secondconvert : array[TConvertType] of pointer = (
           @TTypeConvNode._second_nothing, {none}
           @TTypeConvNode._second_nothing, {equal}
           @TTypeConvNode._second_nothing, {not_possible}
           @TTypeConvNode._second_nothing, {second_string_to_string, handled in resultdef pass }
           @TTypeConvNode._second_char_to_string,
           @TTypeConvNode._second_nothing, {char_to_charray}
           @TTypeConvNode._second_nothing, { pchar_to_string, handled in resultdef pass }
           @TTypeConvNode._second_nothing, {cchar_to_pchar}
           @TTypeConvNode._second_cstring_to_pchar,
           @TTypeConvNode._second_cstring_to_int,
           @TTypeConvNode._second_ansistring_to_pchar,
           @TTypeConvNode._second_string_to_chararray,
           @TTypeConvNode._second_nothing, { chararray_to_string, handled in resultdef pass }
           @TTypeConvNode._second_array_to_pointer,
           @TTypeConvNode._second_pointer_to_array,
           @TTypeConvNode._second_int_to_int,
           @TTypeConvNode._second_int_to_bool,
           @TTypeConvNode._second_bool_to_bool,
           @TTypeConvNode._second_bool_to_int,
           @TTypeConvNode._second_real_to_real,
           @TTypeConvNode._second_int_to_real,
           @TTypeConvNode._second_nothing, { real_to_currency, handled in resultdef pass }
           @TTypeConvNode._second_proc_to_procvar,
           @TTypeConvNode._second_nil_to_methodprocvar,
           @TTypeConvNode._second_nothing, { arrayconstructor_to_set }
           @TTypeConvNode._second_nothing, { second_set_to_set, handled in first pass }
           @TTypeConvNode._second_cord_to_pointer,
           @TTypeConvNode._second_nothing, { interface 2 string }
           @TTypeConvNode._second_nothing, { interface 2 guid   }
           @TTypeConvNode._second_class_to_intf,
           @TTypeConvNode._second_char_to_char,
           @TTypeConvNode._second_nothing,  { dynarray_2_openarray }
           @TTypeConvNode._second_nothing,  { pwchar_2_string }
           @TTypeConvNode._second_nothing,  { variant_2_dynarray }
           @TTypeConvNode._second_nothing,  { dynarray_2_variant}
           @TTypeConvNode._second_nothing,  { variant_2_enum }
           @TTypeConvNode._second_nothing,  { enum_2_variant }
           @TTypeConvNode._second_nothing,  { variant_2_interface }
           @TTypeConvNode._second_nothing,  { interface_2_variant }
           @TTypeConvNode._second_nothing,  { array_2_dynarray }
           @TTypeConvNode._second_elem_to_openarray,  { elem_2_openarray }
           @TTypeConvNode._second_nothing,  { arrayconstructor_2_dynarray }
           @TTypeConvNode._second_nothing,  { arrayconstructor_2_array }
           @TTypeConvNode._second_nothing,  { anonproc_2_funcref }
           @TTypeConvNode._second_nothing   { procvar_2_funcref }
         );
      type
         TProcedureOfObject = procedure of object;

      var
         r : TMethod;

      begin
         { this is a little bit dirty but it works }
         { and should be quite portable too        }
         r.Code:=secondconvert[c];
         r.Data:=self;
         TProcedureOfObject(r)();
      end;

{*****************************************************************************
                                TASNODE
*****************************************************************************}

    function TAsIsNode.target_specific_typecheck: boolean;
      begin
        result:=false;
      end;


    function TAsIsNode.pass_typecheck: TNode;
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
            if Is_InterfaceCOM(left.resultdef) then
              begin
                { relation checks are not possible }
              end
            { or left must be a class }
            else if Is_Class(left.resultdef) then
              begin
                { the operands must be related }
                if (not(Def_Is_Related(TObjectDef(left.resultdef),
                   TObjectDef(TClassRefDef(right.resultdef).PointedDef)))) and
                   (not(Def_Is_Related(TObjectDef(TClassRefDef(right.resultdef).PointedDef),
                   TObjectDef(left.resultdef)))) then
                  CGMessage2(type_e_classes_not_related,
                     FullTypeName(left.resultdef,TClassRefDef(right.resultdef).PointedDef),
                     FullTypeName(TClassRefDef(right.resultdef).PointedDef,left.resultdef));
              end
            else
              CGMessage1(type_e_class_or_cominterface_type_expected,left.resultdef.TypeName);
            case nodetype of
              isn:
                resultdef:=PasBool1Type;
              asn:
                resultdef:=TClassRefDef(right.resultdef).PointedDef;
              else
                ;
            end;
          end
        else if Is_Interface(right.resultdef) or
                Is_DispInterface(right.resultdef) then
          begin
           case nodetype of
             isn:
               resultdef:=PasBool1Type;
             asn:
               resultdef:=right.resultdef;
             else
               ;
           end;

            { left is a class or interface }
            if not(Is_Class(left.resultdef) or
                   Is_InterfaceCOM(left.resultdef)) then
              CGMessage1(type_e_class_or_cominterface_type_expected,left.resultdef.TypeName)
            else
              begin

                { load the GUID of the interface }
                if (right.nodetype=typen) then
                  begin
                    if TObjectDef(right.resultdef).ObjectType=odt_interfacecorba then
                      begin
                        if Assigned(TObjectDef(right.resultdef).IIDStr) then
                          begin
                            if not(oo_has_valid_guid in TObjectDef(right.resultdef).ObjectOptions) and not Is_TypeParam(right.resultdef) then
                              CGMessage1(type_e_interface_has_no_name,TObjectDef(right.resultdef).TypeName);
                            hp:=CStringConstNode.createstr(TObjectDef(right.resultdef).IIDStr^);
                            TStringConstNode(hp).changestringtype(CShortStringType);
                            right.free;
                            right:=hp;
                          end
                        else
                          InternalError(201006131);
                      end
                    else
                      begin
                        if Assigned(TObjectDef(right.resultdef).IIDGUID) then
                          begin
                            if not(oo_has_valid_guid in TObjectDef(right.resultdef).ObjectOptions) and not Is_TypeParam(right.resultdef) then
                              CGMessage1(type_e_interface_has_no_guid,TObjectDef(right.resultdef).TypeName);
                            hp:=CGUIDConstNode.create(TObjectDef(right.resultdef).IIDGUID^);
                            right.free;
                            right:=hp;
                          end
                        else
                          InternalError(201006132);
                      end;
                    TypeCheckPass(right);
                  end;
              end;
          end
        else
          CGMessage1(type_e_class_or_interface_type_expected,right.resultdef.TypeName);
      end;

{*****************************************************************************
                                TISNODE
*****************************************************************************}

    constructor TIsNode.create(l,r : TNode);

      begin
         inherited create(isn,l,r);
      end;


    constructor TIsNode.Create_Internal(l, r: TNode);

      begin
        create(l,r);
        include(flags,nf_internal);
      end;


    function TIsNode.pass_1 : TNode;
      var
        procname: string;
        statement : TStatementNode;
        tempnode : TTempCreateNode;
      begin
        result:=nil;
        { Passing a class type to an "is" expression cannot result in a class
          of that type to be constructed.
        }
        include(right.flags,nf_ignore_for_wpo);

        if Is_Class(left.resultdef) and
           (right.resultdef.typ=classrefdef) then
          begin
            if (right.nodetype=loadvmtaddrn) and
              (TLoadVMTAddrNode(right).left.nodetype=typen) and
              (oo_is_sealed in TObjectDef(TLoadVMTAddrNode(right).left.resultdef).ObjectOptions) and
              Equal_Defs(left.resultdef,TClassRefDef(right.resultdef).PointedDef) then
              begin
                if might_have_sideeffects(left) or
                  (node_complexity(left)>2) then
                  begin
                    result:=internalstatements(statement);
                    tempnode:=CTempCreateNode.create(left.resultdef,left.resultdef.Size,tt_persistent,true);
                    addstatement(statement,tempnode);
                    addstatement(statement,CAssignmentNode.Create_Internal(CTempRefNode.create(tempnode),left));
                    addstatement(statement,CAddNode.Create_Internal(andn,
                      CAddNode.Create_Internal(unequaln,CTempRefNode.create(tempnode),CNilNode.create),
                      CAddNode.Create_Internal(EqualN,CLoadVMTAddrNode.create(CTempRefNode.create(tempnode)),right)
                      )
                    );

                    left:=nil;
                    right:=nil;
                  end
                else
                  begin
                    result:=CAddNode.Create_Internal(andn,
                      CAddNode.Create_Internal(unequaln,left.GetCopy,CNilNode.create),
                      CAddNode.Create_Internal(EqualN,CLoadVMTAddrNode.create(left.GetCopy),right)
                      );
                    right:=nil;
                  end;
              end
            else
              result := CCallNode.createinternres('fpc_do_is',
                CCallParaNode.create(left,CCallParaNode.create(right,nil)),
                resultdef);
          end
        else
          begin
            if Is_Class(left.resultdef) then
              if Is_ShortString(right.resultdef) then
                procname := 'fpc_class_is_corbaintf'
              else
                procname := 'fpc_class_is_intf'
            else
              if right.resultdef.typ=classrefdef then
                procname := 'fpc_intf_is_class'
              else
                procname := 'fpc_intf_is';
            result := CTypeConvNode.Create_Internal(CCallNode.createintern(procname,
               CCallParaNode.create(right,CCallParaNode.create(left,nil))),resultdef);
          end;
        left := nil;
        right := nil;
        //firstpass(call);
        if CodeGenError then
          exit;
      end;

    { dummy pass_2, it will never be called, but we need one since }
    { you can't instantiate an abstract class                      }
    procedure TIsNode.pass_generate_code;
      begin
      end;


{*****************************************************************************
                                TASNODE
*****************************************************************************}

    constructor TAsNode.create(l,r : TNode);

      begin
         inherited create(asn,l,r);
         call := nil;
      end;


    constructor TAsNode.Create_Internal(l,r : TNode);

      begin
        create(l,r);
        include(flags,nf_internal);
      end;


    destructor TAsNode.Destroy;

      begin
        call.free;
        call := nil;
        inherited Destroy;
      end;


    function TAsNode.dogetcopy: TNode;
      begin
        result := inherited dogetcopy;
        if Assigned(call) then
          TAsNode(result).call := call.GetCopy
        else
          TAsNode(result).call := nil;
      end;


    function TAsNode.docompare(p: TNode): boolean;
      begin
        result:=
          inherited docompare(p) and
          TAsNode(p).call.isequal(call);
      end;


    function TAsNode.pass_1 : TNode;
      var
        procname: string;
      begin
        result:=nil;
        { Passing a class type to an "as" expression cannot result in a class
          of that type to be constructed.

          We could put this inside the if-block below, but this way it is
          safe for sure even if the code below changes
        }
        if Assigned(right) then
          include(right.flags,nf_ignore_for_wpo);

        if not Assigned(call) then
          begin
            if Is_Class(left.resultdef) and
               (right.resultdef.typ=classrefdef) then
              call := CCallNode.createinternres('fpc_do_as',
                CCallParaNode.create(left,CCallParaNode.create(right,nil)),
                resultdef)
            else
              begin
                if Is_Class(left.resultdef) then
                  if Is_ShortString(right.resultdef) then
                    procname := 'fpc_class_as_corbaintf'
                  else
                    procname := 'fpc_class_as_intf'
                else
                  if right.resultdef.typ=classrefdef then
                    procname := 'fpc_intf_as_class'
                  else
                    procname := 'fpc_intf_as';
                call := CTypeConvNode.Create_Internal(CCallNode.createintern(procname,
                   CCallParaNode.create(right,CCallParaNode.create(left,nil))),resultdef);
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
