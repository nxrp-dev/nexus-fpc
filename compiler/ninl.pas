{
    Copyright (c) 1998-2007 by Florian Klaempfl

    Type checking and register allocation for inline nodes

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
unit ninl;

{$i fpcdefs.inc}

interface

    uses
       TPCompilerReal,
       node,htypechk,symtype,compinnr;

    type
       TInlineNodeFlag = (
         inf_inlineconst
       );

       TInlineNodeFlags = set of TInlineNodeFlag;

       TInlineNode = class(TUnaryNode)
          inlinenodeflags : TInlineNodeFlags;
          inlinenumber : TInlineNumber;
          constructor create(number : TInlineNumber;is_const:boolean;l : TNode);virtual;
          constructor createintern(number : TInlineNumber;is_const:boolean;l : TNode);virtual;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          function dogetcopy : TNode;override;
          procedure printnodeinfo(var t : text);override;
{$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeInfo(var t : text);override;
{$endif DEBUG_NODE_XML}
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function pass_typecheck_cpu:TNode;virtual;
          function simplify(forinline : boolean): TNode;override;
          function docompare(p: TNode): boolean; override;
          procedure mark_write;override;

          { returns a node tree where the inc/dec are replaced by add/sub }
          function getaddsub_for_incdec : TNode;

          { pack and unpack are changed into for-loops by the compiler }
          function first_pack_unpack: TNode; virtual;

          property parameters : TNode read left write left;

          function may_have_sideeffect_norecurse: boolean;

          function may_ignore_result:boolean;
         protected
          { All the following routines currently
            call compilerprocs, unless they are
            overridden in which case, the code
            generator handles them.
          }
          function first_pi: TNode ; virtual;
          function first_arctan_real: TNode; virtual;
          function first_abs_real: TNode; virtual;
          function first_sqr_real: TNode; virtual;
          function first_sqrt_real: TNode; virtual;
          function first_ln_real: TNode; virtual;
          function first_cos_real: TNode; virtual;
          function first_sin_real: TNode; virtual;
          function first_exp_real: TNode; virtual;
          function first_frac_real: TNode; virtual;
          function first_round_real: TNode; virtual;
          function first_trunc_real: TNode; virtual;
          function first_int_real: TNode; virtual;
          function first_abs_long: TNode; virtual;
          function first_IncDec: TNode; virtual;
          function first_IncludeExclude: TNode; virtual;
          function first_get_frame: TNode; virtual;
          function first_setlength: TNode; virtual;
          function first_copy: TNode; virtual;

          { Internal allocation node; the parser does not emit it. }
          function first_new: TNode; virtual;
          function first_length: TNode; virtual;
          function first_high: TNode; virtual;
          function first_box: TNode; virtual; abstract;
          function first_unbox: TNode; virtual; abstract;
          function first_assigned: TNode; virtual;
          function first_assert: TNode; virtual;
          function first_popcnt: TNode; virtual;
          function first_bitscan: TNode; virtual;
          { override these for Seg() support }
          function typecheck_seg: TNode; virtual;
          function first_seg: TNode; virtual;
          function first_sar: TNode; virtual;
          function first_fma : TNode; virtual;
          function first_minmax: TNode; virtual;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
          function first_ShiftRot_assign_64bitint: TNode; virtual;
{$endif not cpu64bitalu and not cpuhighleveltarget}
          function first_AndOrXorShiftRot_assign: TNode; virtual;
          function first_NegNot_assign: TNode; virtual;
          function first_atomic:TNode;virtual;
          function first_cpu : TNode; virtual;

          procedure CheckParameters(count : integer);
        private
          function handle_str: TNode;
          function handle_reset_rewrite_typed: TNode;
          function handle_text_read_write(filepara,params:TTertiaryNode;var newstatement:TNode):boolean;
          function handle_typed_read_write(filepara,params:TTertiaryNode;var newstatement:TNode):boolean;
          function handle_read_write: TNode;
          function handle_val: TNode;
          function handle_default: TNode;
          function handle_setlength: TNode;
          function handle_copy: TNode;
          function handle_box: TNode;
          function handle_unbox: TNode;
          function handle_insert:TNode;
          function handle_delete:TNode;
          function handle_concat:TNode;
       end;
       TInlineNodeClass = class of TInlineNode;

    var
       CInlineNode : TInlineNodeClass = TInlineNode;

   function geninlinenode(number : TInlineNumber;is_const:boolean;l : TNode) : TInlineNode;

implementation

    uses
      Verbose,Globals,Systems,ConstExp,
      GlobType,CUtils,CClasses,FModule,
      symconst,symdef,SymSym,symcpu,SymTable,paramgr,defcmp,defutil,SymBase,
      CPUInfo,cpubase,
      pass_1,PPU,
      ncal,ncon,ncnv,nadd,nld,nbas,nflw,nmem,nmat,nutils,ngenutil,
      nobjc,objcdef,
      cgbase,ProcInfo;

   function geninlinenode(number : TInlineNumber;is_const:boolean;l : TNode) : TInlineNode;

     begin
        geninlinenode:=CInlineNode.create(number,is_const,l);
     end;

{*****************************************************************************
                           TINLINENODE
*****************************************************************************}

    constructor TInlineNode.create(number : TInlineNumber;is_const:boolean;l : TNode);
      begin
         inherited create(inlinen,l);
         if is_const then
           inlinenodeflags:=[inf_inlineconst]
         else
           inlinenodeflags:=[];
         inlinenumber:=number;
      end;


    constructor TInlineNode.createintern(number : TInlineNumber; is_const : boolean;
     l : TNode);
      begin
         create(number,is_const,l);
         inlinenodeflags:=[];
         include(flags,nf_internal);
      end;


    constructor TInlineNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.GetSet(TPPUSet1(inlinenodeflags));
        inlinenumber:=TInlineNumber(ppufile.GetLongInt);
      end;


    procedure TInlineNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutSet(TPPUSet1(inlinenodeflags));
        ppufile.PutLongInt(LongInt(inlinenumber));
      end;


    function TInlineNode.dogetcopy : TNode;
      var
         n : TInlineNode;
      begin
         n:=TInlineNode(inherited dogetcopy);
         n.inlinenodeflags:=inlinenodeflags;
         n.inlinenumber:=inlinenumber;
         result:=n;
      end;


    procedure TInlineNode.printnodeinfo(var t : text);
      begin
        inherited;
        write(t,', inlinenumber = ',inlinenumber);
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TInlineNode.XMLPrintNodeInfo(var T: Text);
      var
        i: TInlineNodeFlag;
        First: Boolean;
      begin
        inherited XMLPrintNodeInfo(T);
        First := True;
        for i in inlinenodeflags do
          begin
            if First then
              begin
                Write(T, ' inlinenodeflags="', i);
                First := False;
              end
            else
              Write(T, ',', i)
          end;
        if not First then
          Write(T, '"');

        Write(T, ' inlinenumber="', inlinenumber, '"');
      end;
{$endif DEBUG_NODE_XML}

    function get_str_int_func(def: TDef): string;
    var
      OrdType: TOrdType;
    begin
      OrdType := TOrdDef(def).OrdType;
      if not (OrdType in [scurrency,s64bit,u64bit,s32bit,u32bit,s16bit,u16bit,s8bit,u8bit]) then
        InternalError(2013032603);

      if Is_OversizedOrd(def) then
        begin
          case OrdType of
            scurrency,
            s64bit: exit('int64');
            u64bit: exit('qword');
            s32bit: exit('longint');
            u32bit: exit('longword');
            s16bit: exit('smallint');
            u16bit: exit('word');
            else
              InternalError(2013032604);
          end;
        end
      else
        begin
          if Is_NativeUInt(def) then
            exit('uint')
          else
            exit('sint');
        end;
      InternalError(2013032605);
    end;


    function TInlineNode.handle_str : TNode;
      var
        lenpara,
        fracpara,
        newparas,
        tmppara,
        dest,
        source  : TCallParaNode;
        procname: string;
        Is_Real,Is_Enum : boolean;
        rt : aint;
        intrinsiccode: TInlineNumber;

      begin
        result := CErrorNode.create;

        { get destination string }
        dest := TCallParaNode(left);

        { get source para (number) }
        source := dest;
        while Assigned(source.right) do
          source := TCallParaNode(source.right);

        { destination parameter must be a normal (not a colon) parameter, this
          check is needed because str(v:len) also has 2 parameters }
        if (source=dest) or
           (cpf_is_colon_para in TCallParaNode(dest).callparaflags) then
          begin
            CGMessage1(parser_e_wrong_parameter_size,'Str');
            exit;
          end;

        { in case we are in a generic definition, we cannot
          do all checks, the parameters might be type parameters,

          bailout as well in case of an error before }
        if (df_generic in CurrentProcInfo.procdef.DefOptions) or
         (dest.resultdef.typ=errordef) or
         (source.resultdef.typ=errordef) then
          begin
            result.Free;
            result:=nil;
            resultdef:=VoidType;
            exit;
          end;

        Is_Real:=(source.resultdef.typ = floatdef) or Is_Currency(source.resultdef);
        Is_Enum:=source.left.resultdef.typ=enumdef;

        if ((dest.left.resultdef.typ<>stringdef) and
            not(Is_CharArray(dest.left.resultdef))) or
           not(Is_Real or Is_Enum or
               (source.left.resultdef.typ=orddef)) then
          begin
            CGMessagePos1(source.fileinfo,
              type_e_integer_expr_expected,source.resultdef.TypeName);
            exit;
          end;

        { get len/frac parameters }
        lenpara := nil;
        fracpara := nil;
        if (cpf_is_colon_para in TCallParaNode(dest.right).callparaflags) then
          begin
            lenpara := TCallParaNode(dest.right);

            { we can let the callnode do the type checking of these parameters too, }
            { but then the error messages aren't as nice                            }
            if not Is_Integer(lenpara.resultdef) then
              begin
                CGMessagePos1(lenpara.fileinfo,
                  type_e_integer_expr_expected,lenpara.resultdef.TypeName);
                exit;
              end;
            if (cpf_is_colon_para in TCallParaNode(lenpara.right).callparaflags) then
              begin
                { parameters are in reverse order! }
                fracpara := lenpara;
                lenpara := TCallParaNode(lenpara.right);
                if not Is_Real then
                  begin
                    CGMessagePos(lenpara.fileinfo,parser_e_illegal_colon_qualifier);
                    exit
                  end;
                if not Is_Integer(lenpara.resultdef) then
                  begin
                    CGMessagePos1(lenpara.fileinfo,
                      type_e_integer_expr_expected,lenpara.resultdef.TypeName);
                    exit;
                  end;
              end;
          end;

        { generate the parameter list for the compilerproc }
        newparas := dest;

        { if we have a float parameter, insert the realtype, len and fracpara parameters }
        if Is_Real then
          begin
            { insert realtype parameter }
            if not Is_Currency(source.resultdef) then
              begin
                rt:=ord(TFloatDef(source.left.resultdef).FloatType);
                newparas.right := CCallParaNode.create(COrdConstNode.create(
                  rt,S32IntType,true),newparas.right);
                tmppara:=TCallParaNode(newparas.right);
              end
            else
              tmppara:=newparas;
            { if necessary, insert a fraction parameter }
            if not Assigned(fracpara) then
              begin
                tmppara.right := CCallParaNode.create(
                  COrdConstNode.create(int64(-1),S32IntType,false),
                   tmppara.right);
                fracpara := TCallParaNode(tmppara.right);
              end;
            { if necessary, insert a length para }
            if not Assigned(lenpara) then
              fracpara.right := CCallParaNode.create(
                COrdConstNode.create(int64(-32767),S32IntType,false),
                   fracpara.right);
          end
        else if Is_Enum then
          begin
            {Insert a reference to the ord2string index.}
            newparas.right:=CCallParaNode.create(
              CAddrNode.Create_Internal(
                CRTTINode.create(TEnumDef(source.left.resultdef),fullrtti,rdt_normal)
              ),
              newparas.right);
            {Insert a reference to the typinfo.}
            newparas.right:=CCallParaNode.create(
              CAddrNode.Create_Internal(
                CRTTINode.create(TEnumDef(source.left.resultdef),fullrtti,rdt_ord2str)
              ),
              newparas.right);
            {Insert a type conversion from the enumeration to longint.}
            source.left:=CTypeConvNode.Create_Internal(source.left,S32IntType);
            TypeCheckPass(source.left);

            { if necessary, insert a length para }
            if not Assigned(lenpara) then
              TCallParaNode(TCallParaNode(newparas.right).right).right:=
                CCallParaNode.create(
                  COrdConstNode.create(int64(-1),S32IntType,false),
                  TCallParaNode(TCallParaNode(newparas.right).right).right
                );
          end
        else
          { for a normal parameter, insert a only length parameter if one is missing }
          if not Assigned(lenpara) then
            newparas.right := CCallParaNode.create(COrdConstNode.create(int64(-1),S32IntType,false),
              newparas.right);

        { remove the parameters from the original node so they won't get disposed, }
        { since they're reused                                                     }
        left := nil;

        intrinsiccode := Default(TInlineNumber);

        { create procedure name }
        if Is_CharArray(dest.resultdef) then
          procname:='fpc_chararray_'
        else
          procname := 'fpc_' + TStringDef(dest.resultdef).StringTypName+'_';
        if Is_Real then
          if Is_Currency(source.resultdef) then
            procname := procname + 'currency'
          else
            procname := procname + 'float'
        else if Is_Enum then
          procname:=procname+'enum'
        else
          case TOrdDef(source.resultdef).OrdType of
            pasbool1,pasbool8,pasbool16,pasbool32,pasbool64,
            bool8bit,bool16bit,bool32bit,bool64bit:
              procname := procname + 'bool';

            scurrency,s64bit,u64bit,s32bit,u32bit,s16bit,u16bit,s8bit,u8bit:
              begin
                intrinsiccode := in_str_x_string;
                procname := procname + get_str_int_func(source.resultdef);
              end;

            else
              begin
                CGMessagePos1(source.fileinfo,
                  type_e_integer_expr_expected,TOrdDef(source.resultdef).TypeName);
                exit;
              end;
          end;

        { for ansistrings insert the encoding argument }
        if Is_AnsiString(dest.resultdef) then
          newparas:=CCallParaNode.create(COrdConstNode.create(
            GetParaEncoding(dest.resultdef),U16IntType,true),newparas);

        { free the errornode we generated in the beginning }
        result.free;
        { create the call node, }
        result := CCallNode.createfromintrinsic(intrinsiccode,procname,newparas);
      end;


    function TInlineNode.handle_default: TNode;

      function getdefaultvarsym(def:TDef):TNode;
        var
          hashedid : THashedIDString;
          srsym : TSym;
          srsymtable : TSymTable;
          defaultname : TIDString;
          VarSpez : TVarSpez;
        begin
          if not Assigned(def) or
              not (def.typ in [arraydef,recorddef,variantdef,objectdef,procvardef]) or
              ((def.typ=objectdef) and not Is_Object(def)) then
            InternalError(201202101);

          { extra '$' prefix because on darwin the result of makemangledname
            is prefixed by '_' and hence adding a '$' at the start of the
            prefix passed to makemangledname doesn't help (the whole point of
            the copy() operation below is to ensure that the id does not start
            with a '$', because that is interpreted specially by the symtable
            routines -- that's also why we prefix with '$_', so it will still
            work if make_mangledname() would somehow return a name that already
            starts with '$' }
          defaultname:='$_'+Make_MangledName('zero',def.owner,def.TypeSym.Name);
          { can't hardcode the position of the '$', e.g. on darwin an underscore
            is added }
          hashedid.id:=copy(defaultname,2,255);
          { in case of a previous error, current_procinfo might not be set
            so avoid a crash in this case }
          if Assigned(CurrentProcInfo) then
            begin
              { the default sym is always part of the current procedure/function }
              srsymtable:=CurrentModule.LocalSymTable;
              srsym:=TSym(srsymtable.findwithhash(hashedid));
              if not Assigned(srsym) then
                begin
                  VarSpez:=vs_const;
                  { if we have an initialize or finalize management operator then
                    we may not declare this as const as the unit init-/finalization
                    needs to be able to modify it }
                  if (def.typ=recorddef) and (mop_initialize in TRecordSymTable(TRecordDef(def).SymTable).ManagementOperators) then
                    VarSpez:=vs_var;
                  { no valid default variable found, so create it }
                  srsym:=CStaticVarSym.create(defaultname,VarSpez,def,[]);
                  { mark the staticvarsym as typedconst }
                  if VarSpez=vs_const then
                    include(TAbstractVarSym(srsym).VarOptions,vo_is_typed_const);
                  include(TAbstractVarSym(srsym).VarOptions,vo_is_default_var);
                  { There is no reliable way to be sure that this symbol will not be used
                    later on inside some inlined code, so mark it as global }
                  include(TAbstractVarSym(srsym).VarOptions,vo_is_public);
                  { The variable has a value assigned }
                  TAbstractVarSym(srsym).VarState:=vs_initialised;

                  srsymtable.InsertSym(srsym);
                  CNodeUtils.insertbssdata(TStaticVarSym(srsym));
                end;
              result:=CLoadNode.create(srsym,srsymtable);
            end
          else
            result:=CErrorNode.create;
        end;

      var
        def : TDef;
      begin
        if not Assigned(left) or (left.nodetype<>typen) then
          InternalError(2012032102);

        def:=TTypeNode(left).typedef;
        if Assigned(CurrentProcInfo) and
           (df_generic in CurrentProcInfo.procdef.DefOptions) then
          begin
            { don't allow as a default parameter value, because it may not be valid
              when specialising }
            if Block_Type<>bt_const then
              result:=CPointerConstNode.create(0,def)
            else
              result:=CErrorNode.create;
            exit;
          end;

        result:=nil;
        case def.typ of
          enumdef,
          orddef:
            { don't do a rangecheck as Default will also return 0
              for the following types (Delphi compatible):
              TRange1 = -10..-5;
              TRange2 = 5..10;
              TEnum = (a:=5;b:=10); }
            result:=COrdConstNode.create(0,def,false);
          classrefdef,
          pointerdef:
            result:=CPointerConstNode.create(0,def);
          procvardef:
            if TProcVarDef(def).Size<>sizeof(PInt) then
              result:=getdefaultvarsym(def)
            else
              result:=CPointerConstNode.create(0,def);
          stringdef:
            result:=CStringConstNode.createstr('');
          floatdef:
            result:=CRealConstNode.create(0,def);
          objectdef:
            begin
              if Is_Implicit_Pointer_Object_Type(def) then
                result:=CPointerConstNode.create(0,def)
              else
                if Is_Object(def) then
                  begin
                    { Delphi does not recursively check whether
                      an object contains unsupported types }
                    if not (m_delphi in CurrentSettings.ModeSwitches) and
                        not is_valid_for_default(def) then
                      Message(type_e_type_not_allowed_for_default);
                    result:=getdefaultvarsym(def);
                  end
                else
                  Message(type_e_type_not_allowed_for_default);
            end;
          variantdef,
          recorddef:
            begin
              { Delphi does not recursively check whether a record
                contains unsupported types }
              if (def.typ=recorddef) and not (m_delphi in CurrentSettings.ModeSwitches) and
                  not is_valid_for_default(def) then
                Message(type_e_type_not_allowed_for_default);
              result:=getdefaultvarsym(def);
            end;
          setdef:
            begin
              result:=CSetConstNode.create(nil,def);
              New(TSetConstNode(result).value_set);
              TSetConstNode(result).value_set^:=[];
            end;
          arraydef:
            begin
              { can other array types be parsed by single_type? }
              if ado_isdynamicarray in TArrayDef(def).ArrayOptions then
                result:=CPointerConstNode.create(0,def)
              else
                begin
                  result:=getdefaultvarsym(def);
                end;
            end;
          undefineddef:
            begin
              if sp_generic_dummy in def.TypeSym.SymOptions then
                begin
                  { this matches the error messages that are printed
                    in case of non-Delphi modes }
                  Message(parser_e_no_generics_as_types);
                  Message(type_e_type_id_expected);
                end
              else
                result:=CPointerConstNode.create(0,def);
            end;
          else
            Message(type_e_type_not_allowed_for_default);
        end;
        if not Assigned(result) then
          result:=CErrorNode.create;
      end;


    function TInlineNode.handle_reset_rewrite_typed: TNode;
      begin
        { since this is a "in_xxxx_typedfile" node, we can be sure we have  }
        { a typed file as argument and we don't have to check it again (JM) }

        { add the recsize parameter }

        { iso mode extension with name? }
        if inlinenumber in [in_reset_typedfile_name,in_rewrite_typedfile_name] then
          begin
            left := CCallParaNode.create(COrdConstNode.create(
              TFileDef(TCallParaNode(TCallParaNode(left).nextpara).paravalue.resultdef).TypedFileDef.Size,S32IntType,true),left);
          end
        else
          begin
            { note: for some reason, the parameter of intern procedures with only one }
            {   parameter is gets lifted out of its original tcallparanode (see round }
            {   line 1306 of ncal.pas), so recreate a tcallparanode here (JM)         }
            left := CCallParaNode.create(COrdConstNode.create(
              TFileDef(left.resultdef).TypedFileDef.Size,S32IntType,true),
              CCallParaNode.create(left,nil));
          end;
        { create the correct call }
        if m_isolike_io in CurrentSettings.ModeSwitches then
          begin
            case inlinenumber of
              in_reset_typedfile:
                result := CCallNode.createintern('fpc_reset_typed_iso',left);
              in_reset_typedfile_name:
                result := CCallNode.createintern('fpc_reset_typed_name_iso',left);
              in_rewrite_typedfile:
                result := CCallNode.createintern('fpc_rewrite_typed_iso',left);
              in_rewrite_typedfile_name:
                result := CCallNode.createintern('fpc_rewrite_typed_name_iso',left);
              else
                InternalError(2016101502);
            end;
          end
        else
          begin
            if inlinenumber=in_reset_typedfile then
              result := CCallNode.createintern('fpc_reset_typed',left)
            else
              result := CCallNode.createintern('fpc_rewrite_typed',left);
          end;

        { make sure left doesn't get disposed, since we use it in the new call }
        left := nil;
      end;


    procedure maybe_convert_to_string(var n: TNode);
      begin
        { stringconstnodes are arrays of char. It's much more }
        { efficient to write a constant string, so convert    }
        { either to shortstring or ansistring depending on    }
        { length                                              }
        if (n.nodetype=stringconstn) then
          if Is_CharArray(n.resultdef) then
            if (TStringConstNode(n).len<=255) then
              inserttypeconv(n,CShortStringType)
            else
              inserttypeconv(n,GetAnsiStringDef)
          else if Is_WideCharArray(n.resultdef) then
            inserttypeconv(n,CUnicodeStringType);
      end;


    procedure get_read_write_int_func(def: TDef; out func_suffix: ShortString; out readfunctype: TDef);
    var
      OrdType: TOrdType;
    begin
      OrdType := TOrdDef(def).OrdType;
      if Is_OversizedInt(def) then
        begin
          case OrdType of
            s64bit:
              begin
                func_suffix := 'int64';
                readfunctype:=S64IntType;
              end;
            u64bit :
              begin
                func_suffix := 'qword';
                readfunctype:=U64IntType;
              end;
            s32bit:
              begin
                func_suffix := 'longint';
                readfunctype:=S32IntType;
              end;
            u32bit :
              begin
                func_suffix := 'longword';
                readfunctype:=U32IntType;
              end;
            s16bit:
              begin
                func_suffix := 'smallint';
                readfunctype:=S16IntType;
              end;
            u16bit :
              begin
                func_suffix := 'word';
                readfunctype:=U16IntType;
              end;
            else
              InternalError(2013032602);
          end;
        end
      else
        begin
          case OrdType of
            s64bit,
            s32bit,
            s16bit,
            s8bit:
              begin
                func_suffix := 'sint';
                readfunctype := SIntType;
              end;
            u64bit,
            u32bit,
            u16bit,
            u8bit:
              begin
                func_suffix := 'uint';
                readfunctype := UIntType;
              end;
            else
              InternalError(2013032601);
          end;
        end;
    end;


    function TInlineNode.handle_text_read_write(filepara,params:TTertiaryNode;var newstatement:TNode):boolean;

    {Read(ln)/write(ln) for text files.}

    const  procprefixes:array[boolean] of string[15]=('fpc_write_text_','fpc_read_text_');

    var error_para,Is_Real,special_handling,found_error,do_read:boolean;
        p1:TNode;
        nextpara,
        indexpara,
        lenpara,
        para,
        fracpara:TCallParaNode;
        temp:TTempCreateNode;
        readfunctype:TDef;
        name:string[63];
        func_suffix:string[8];

    begin
      para:=TCallParaNode(params);
      found_error:=false;
      do_read:=inlinenumber in [in_read_x,in_readln_x,in_readstr_x];
      name:='';
      while Assigned(para) do
        begin
          { is this parameter faulty? }
          error_para:=false;
          { is this parameter a real? }
          Is_Real:=false;
          { type used for the read(), this is used to check
            whether a temp is needed for range checking }
          readfunctype:=nil;

          { can't read/write types }
          if (para.left.nodetype=typen) and not(Is_TypeParam(TTypeNode(para.left).typedef)) then
            begin
              CGMessagePos(para.fileinfo,type_e_cant_read_write_type);
              error_para := true;
            end;

          { support writeln(procvar) }
          if para.left.resultdef.typ=procvardef then
            begin
              p1:=CCallNode.create_procvar(nil,para.left);
              TypeCheckPass(p1);
              para.left:=p1;
            end;

          if inlinenumber in [in_write_x,in_writeln_x] then
            { prefer strings to chararrays }
            maybe_convert_to_string(para.left);
          if Is_TypeParam(para.left.resultdef) then
            error_para:=true
          else
            case para.left.resultdef.typ of
              stringdef :
                begin
                  name:=procprefixes[do_read]+TStringDef(para.left.resultdef).StringTypName;
                  if (m_isolike_io in CurrentSettings.ModeSwitches) and (TStringDef(para.left.resultdef).StringType<>st_shortstring) then
                    begin
                      CGMessagePos(para.fileinfo,type_e_cant_read_write_type_in_iso_mode);
                      error_para := true;
                    end;
                end;
              pointerdef :
                begin
                  if (not Is_PChar(para.left.resultdef)) or do_read then
                    begin
                      CGMessagePos(para.fileinfo,type_e_cant_read_write_type);
                      error_para := true;
                    end
                  else
                    name:=procprefixes[do_read]+'pchar_as_pointer';
                end;
              floatdef :
                begin
                  Is_Real:=true;
                  if TFloatDef(para.left.resultdef).FloatType=s64currency then
                    name := procprefixes[do_read]+'currency'
                  else
                    begin
                      name := procprefixes[do_read]+'float';
                      readfunctype:=PBestRealType^;
                    end;
                  { iso pascal needs a different handler }
                  if (m_isolike_io in CurrentSettings.ModeSwitches) and do_read then
                    name:=name+'_iso';
                end;
              enumdef:
                begin
                  if m_isolike_io in CurrentSettings.ModeSwitches then
                    begin
                      error_para := true;
                      CGMessagePos(para.fileinfo,type_e_cant_read_write_type);
                    end;

                  name:=procprefixes[do_read]+'enum';
                  if do_read then
                    { read is done with a var parameter so we need the correct
                      size for that }
                    case para.left.resultdef.Size of
                      1:
                        begin
                          name:=name+'_shortint';
                          readfunctype:=S8IntType;
                        end;
                      2:
                        begin
                          name:=name+'_smallint';
                          readfunctype:=S16IntType;
                        end;
                      4:
                        begin
                          name:=name+'_longint';
                          readfunctype:=S32IntType;
                        end;
                      else
                        InternalError(2022082601);
                    end
                  else
                    readfunctype:=S32IntType;
                end;
              orddef :
                begin
                  case TOrdDef(para.left.resultdef).OrdType of
                    s8bit,
                    s16bit,
                    s32bit,
                    s64bit,
                    u8bit,
                    u16bit,
                    u32bit,
                    u64bit:
                      begin
                        get_read_write_int_func(para.left.resultdef,func_suffix,readfunctype);
                        name := procprefixes[do_read]+func_suffix;
                        if (m_isolike_io in CurrentSettings.ModeSwitches) and do_read then
                          name:=name+'_iso';
                      end;
                    uchar :
                      begin
                        name := procprefixes[do_read]+'char';
                        { iso pascal needs a different handler }
                        if (m_isolike_io in CurrentSettings.ModeSwitches) and do_read then
                          name:=name+'_iso';
                        readfunctype:=CAnsiCharType;
                      end;
                    uwidechar :
                      begin
                        name := procprefixes[do_read]+'widechar';
                        readfunctype:=CWideCharType;
                      end;
                    scurrency:
                      begin
                        name := procprefixes[do_read]+'currency';
                        { iso pascal needs a different handler }
                        if (m_isolike_io in CurrentSettings.ModeSwitches) and do_read then
                          name:=name+'_iso';
                        readfunctype:=S64CurrencyType;
                        Is_Real:=true;
                      end;
                    pasbool1,
                    pasbool8,
                    pasbool16,
                    pasbool32,
                    pasbool64,
                    bool8bit,
                    bool16bit,
                    bool32bit,
                    bool64bit:
                      if do_read then
                        begin
                          CGMessagePos(para.fileinfo,type_e_cant_read_write_type);
                          error_para := true;
                        end
                      else
                        begin
                          name := procprefixes[do_read]+'boolean';
                          readfunctype:=PasBool1Type;
                        end
                    else
                      begin
                        CGMessagePos(para.fileinfo,type_e_cant_read_write_type);
                        error_para := true;
                      end;
                  end;
                end;
              variantdef :
                begin
                  name:=procprefixes[do_read]+'variant';
                  include(CurrentModule.ModuleFlags,mf_uses_variants);
                end;
              arraydef :
                begin
                  if Is_CharArray(para.left.resultdef) then
                    name := procprefixes[do_read]+'pchar_as_array'
                  else
                    begin
                      CGMessagePos(para.fileinfo,type_e_cant_read_write_type);
                      error_para := true;
                    end
                end;
              else
                begin
                  CGMessagePos(para.fileinfo,type_e_cant_read_write_type);
                  error_para := true;
                end;
            end;

          { iso pascal needs a different handler }
          if (m_isolike_io in CurrentSettings.ModeSwitches) and not(do_read) then
            name:=name+'_iso';

          { check for length/fractional colon para's }
          fracpara:=nil;
          lenpara:=nil;
          indexpara:=nil;
          if Assigned(para.right) and
             (cpf_is_colon_para in TCallParaNode(para.right).callparaflags) then
            begin
              lenpara := TCallParaNode(para.right);
              if Assigned(lenpara.right) and
                 (cpf_is_colon_para in TCallParaNode(lenpara.right).callparaflags) then
                fracpara:=TCallParaNode(lenpara.right);
            end;
          { get the next parameter now already, because we're going }
          { to muck around with the pointers                        }
          if Assigned(fracpara) then
            nextpara := TCallParaNode(fracpara.right)
          else if Assigned(lenpara) then
            nextpara := TCallParaNode(lenpara.right)
          else
            nextpara := TCallParaNode(para.right);

          { check if a fracpara is allowed }
          if Assigned(fracpara) and not Is_Real then
            begin
              CGMessagePos(fracpara.fileinfo,parser_e_illegal_colon_qualifier);
              error_para := true;
            end
          else if Assigned(lenpara) and do_read then
            begin
              { I think this is already filtered out by parsing, but I'm not sure (JM) }
              CGMessagePos(lenpara.fileinfo,parser_e_illegal_colon_qualifier);
              error_para := true;
            end;

          { adjust found_error }
          found_error := found_error or error_para;

          if not error_para then
            begin
              special_handling:=false;
              { create dummy frac/len para's if necessary }
              if not do_read then
                begin
                  { difference in default value for floats and the rest :( }
                  if not Is_Real then
                    begin
                      if not Assigned(lenpara) then
                        begin
                          if m_isolike_io in CurrentSettings.ModeSwitches then
                            lenpara := CCallParaNode.create(
                              COrdConstNode.create(-1,S32IntType,false),nil)
                          else
                            lenpara := CCallParaNode.create(
                              COrdConstNode.create(0,S32IntType,false),nil);
                        end
                      else
                        { make sure we don't pass the successive }
                        { parameters too. We also already have a }
                        { reference to the next parameter in     }
                        { nextpara                               }
                        lenpara.right := nil;
                    end
                  else
                    begin
                      if not Assigned(lenpara) then
                        lenpara := CCallParaNode.create(
                          COrdConstNode.create(int64(-32767),S32IntType,false),nil);
                      { also create a default fracpara if necessary }
                      if not Assigned(fracpara) then
                        fracpara := CCallParaNode.create(
                          COrdConstNode.create(int64(-1),S32IntType,false),nil);
                      { add it to the lenpara }
                      lenpara.right := fracpara;
                      if not Is_Currency(para.left.resultdef) then
                        begin
                          { and add the realtype para (this also removes the link }
                          { to any parameters coming after it)                    }
                          fracpara.right := CCallParaNode.create(
                              COrdConstNode.create(ord(TFloatDef(para.left.resultdef).FloatType),
                              S32IntType,true),nil);
                        end
                      else
                        fracpara.right:=nil;
                    end;
                  if para.left.resultdef.typ=enumdef then
                    begin
                      {To write(ln) an enum we need a some extra parameters.}
                      {Insert a reference to the ord2string index.}
                      indexpara:=CCallParaNode.create(
                        CAddrNode.Create_Internal(
                          CRTTINode.create(TEnumDef(para.left.resultdef),fullrtti,rdt_normal)
                        ),
                        nil);
                      {Insert a reference to the typinfo.}
                      indexpara:=CCallParaNode.create(
                        CAddrNode.Create_Internal(
                         CRTTINode.create(TEnumDef(para.left.resultdef),fullrtti,rdt_ord2str)
                        ),
                        indexpara);
                      {Insert a type conversion to to convert the enum to longint.}
                      para.left:=CTypeConvNode.Create_Internal(para.left,S32IntType);
                      TypeCheckPass(para.left);
                    end;
                end
              else
                begin
                  {To read(ln) an enum we need a an extra parameter.}
                  if para.left.resultdef.typ=enumdef then
                    begin
                      {Insert a reference to the string2ord index.}
                      indexpara:=CCallParaNode.create(CAddrNode.Create_Internal(
                        CRTTINode.create(TEnumDef(para.left.resultdef),fullrtti,rdt_str2ord)
                      ),nil);
                      {Insert a type conversion to to convert the enum to longint.}
                      para.left:=CTypeConvNode.Create_Internal(para.left,readfunctype);
                      TypeCheckPass(para.left);
                    end;
                  { special handling of reading small numbers, because the helpers  }
                  { expect a longint/card/bestreal var parameter. Use a temp. can't }
                  { use functions because then the call to FPC_IOCHECK destroys     }
                  { their result before we can store it                             }
                  if (readfunctype<>nil) and (para.left.resultdef<>readfunctype) then
                    special_handling:=true;
                end;
              if special_handling then
                begin
                  { since we're not going to pass the parameter as var-parameter }
                  { to the read function, manually check whether the parameter   }
                  { can be used as var-parameter (e.g., whether it isn't a       }
                  { property)                                                    }
                  valid_for_var(para.left,true);

                  { create the parameter list: the temp ... }
                  temp := CTempCreateNode.create(readfunctype,readfunctype.Size,tt_persistent,false);
                  addstatement(TStatementNode(newstatement),temp);

                  { ... and the file }
                  p1 := CCallParaNode.create(CTempRefNode.create(temp),
                    filepara.GetCopy);
                  TCallParaNode(TCallParaNode(p1).right).right:=indexpara;

                  { create the call to the helper }
                  addstatement(TStatementNode(newstatement),
                    CCallNode.createintern(name,TCallParaNode(p1)));

                  { assign the result to the original var (this automatically }
                  { takes care of range checking)                             }
                  addstatement(TStatementNode(newstatement),
                    CAssignmentNode.create(para.left,
                      CTempRefNode.create(temp)));

                  { release the temp location }
                  addstatement(TStatementNode(newstatement),CTempDeleteNode.create(temp));

                  { statement of para is used }
                  para.left := nil;

                  { free the enclosing tcallparanode, but not the }
                  { parameters coming after it                    }
                  para.right := nil;
                  para.free;
                  para := nil;
                end
              else
                { read of non s/u-8/16bit, or a write }
                begin
                  { add the filepara to the current parameter }
                  para.right := filepara.GetCopy;
                  {Add the lenpara and the indexpara(s) (fracpara and realtype are
                   already linked with the lenpara if necessary).}
                  if indexpara=nil then
                    TCallParaNode(para.right).right:=lenpara
                  else
                    begin
                      if lenpara=nil then
                        TCallParaNode(para.right).right:=indexpara
                      else
                        begin
                          TCallParaNode(para.right).right:=lenpara;
                          lenpara.right:=indexpara;
                        end;
{                      indexpara.right:=lenpara;}
                    end;
                  { in case of writing a chararray, add whether it's zero-based }
                  if para.left.resultdef.typ=arraydef then
                    para := CCallParaNode.create(COrdConstNode.create(
                      ord(TArrayDef(para.left.resultdef).LowRange=0),PasBool1Type,false),para)
                  else
                  { in case of reading an ansistring pass a codepage argument }
                  if do_read and Is_AnsiString(para.left.resultdef) then
                    para:=CCallParaNode.create(COrdConstNode.create(
                      GetParaEncoding(para.left.resultdef),U16IntType,true),para);
                  { create the call statement }
                  addstatement(TStatementNode(newstatement),
                    CCallNode.createintern(name,para));
                end
            end
          else
            { error_para = true }
            begin
              { free the parameter, since it isn't referenced anywhere anymore }
              para.right := nil;
              para.free;
              para := nil;
              if Assigned(lenpara) then
                begin
                  lenpara.right := nil;
                  lenpara.free;
                  lenpara := nil;
                end;
              if Assigned(fracpara) then
                begin
                  fracpara.right := nil;
                  fracpara.free;
                  fracpara := nil;
                end;
            end;

          { process next parameter }
          para := nextpara;
        end;

      { if no error, add the write(ln)/read(ln) end calls }
      if not found_error then
        begin
          case inlinenumber of
            in_read_x,
            in_readstr_x:
              name:='fpc_read_end';
            in_write_x,
            in_writestr_x:
              name:='fpc_write_end';
            in_readln_x:
              begin
                name:='fpc_readln_end';
                if m_isolike_io in CurrentSettings.ModeSwitches then
                  name:=name+'_iso';
              end;
            in_writeln_x:
              name:='fpc_writeln_end';
            else
              InternalError(2019050501);
          end;
          addstatement(TStatementNode(newstatement),CCallNode.createintern(name,filepara.GetCopy));
        end;
      handle_text_read_write:=found_error;
    end;

    function TInlineNode.handle_typed_read_write(filepara,params:TTertiaryNode;var newstatement:TNode):boolean;

    {Read/write for typed files.}

    const  procprefixes:array[boolean,boolean] of string[19]=(('fpc_typed_write','fpc_typed_read'),
                                                              ('fpc_typed_write','fpc_typed_read_iso'));
           procnamesdisplay:array[boolean,boolean] of string[8] = (('Write','Read'),('WriteStr','ReadStr'));

    var found_error,do_read,is_rwstr:boolean;
        para,nextpara:TCallParaNode;
        p1:TNode;
        temp:TTempCreateNode;
    begin
      found_error:=false;
      para:=TCallParaNode(params);
      do_read:=inlinenumber in [in_read_x,in_readln_x,in_readstr_x];
      is_rwstr := inlinenumber in [in_readstr_x,in_writestr_x];
      temp:=nil;
      { add the typesize to the filepara }
      if filepara.resultdef.typ=filedef then
        filepara.right := CCallParaNode.create(COrdConstNode.create(
          TFileDef(filepara.resultdef).TypedFileDef.Size,S32IntType,true),nil);

      { check for "no parameters" (you need at least one extra para for typed files) }
      if not Assigned(para) then
        begin
          CGMessage1(parser_e_wrong_parameter_size,procnamesdisplay[is_rwstr,do_read]);
          found_error := true;
        end;

      { process all parameters }
      while Assigned(para) do
        begin
          { check if valid parameter }
          if para.left.nodetype=typen then
            begin
              CGMessagePos(para.left.fileinfo,type_e_cant_read_write_type);
              found_error := true;
            end;

          { support writeln(procvar) }
          if (para.left.resultdef.typ=procvardef) then
            begin
              p1:=CCallNode.create_procvar(nil,para.left);
              TypeCheckPass(p1);
              para.left:=p1;
            end;

          if filepara.resultdef.typ=filedef then
            inserttypeconv(para.left,TFileDef(filepara.resultdef).TypedFileDef);

          if Assigned(para.right) and
            (cpf_is_colon_para in TCallParaNode(para.right).callparaflags) then
            begin
              CGMessagePos(para.right.fileinfo,parser_e_illegal_colon_qualifier);

              { skip all colon para's }
              nextpara := TCallParaNode(TCallParaNode(para.right).right);
              while Assigned(nextpara) and (cpf_is_colon_para in nextpara.callparaflags) do
                nextpara := TCallParaNode(nextpara.right);
              found_error := true;
            end
          else
            { get next parameter }
            nextpara := TCallParaNode(para.right);

          { When we have a call, we have a problem: you can't pass the  }
          { result of a call as a formal const parameter. Solution:     }
          { assign the result to a temp and pass this temp as parameter }
          { This is not very efficient, but write(typedfile,x) is       }
          { already slow by itself anyway (no buffering) (JM)           }
          { Actually, thge same goes for every non-simple expression    }
          { (such as an addition, ...) -> put everything but load nodes }
          { into temps (JM)                                             }
          { of course, this must only be allowed for writes!!! (JM)     }
          if not(do_read) and (para.left.nodetype <> loadn) then
            begin
              { create temp for result }
              temp := CTempCreateNode.create(para.left.resultdef,
                para.left.resultdef.Size,tt_persistent,false);
              addstatement(TStatementNode(newstatement),temp);
              { assign result to temp }
              addstatement(TStatementNode(newstatement),
               CAssignmentNode.create(CTempRefNode.create(temp),
                 para.left));
              { replace (reused) paranode with temp }
              para.left := CTempRefNode.create(temp);
            end;
          { add fileparameter }
          para.right := filepara.GetCopy;

          { create call statement                                            }
          { since the parameters are in the correct order, we have to insert }
          { the statements always at the end of the current block            }
          addstatement(TStatementNode(newstatement),
            CCallNode.createintern(procprefixes[m_isolike_io in CurrentSettings.ModeSwitches,do_read],para
          ));

          { if we used a temp, free it }
          if para.left.nodetype = temprefn then
            addstatement(TStatementNode(newstatement),CTempDeleteNode.create(temp));

          { process next parameter }
          para := nextpara;
        end;

      handle_typed_read_write:=found_error;
    end;

    function TInlineNode.handle_read_write: TNode;

      var
        filepara,
        nextpara,
        params   : TCallParaNode;
        newstatement  : TStatementNode;
        newblock      : TBlockNode;
        filetemp      : TTempCreateNode;
        name          : string[31];
        textsym       : TTypeSym;
        is_typed,
        do_read,
        is_rwstr,
        found_error   : boolean;
      begin
        filepara := nil;
        is_typed := false;
        filetemp := nil;
        do_read := inlinenumber in [in_read_x,in_readln_x,in_readstr_x];
        is_rwstr := inlinenumber in [in_readstr_x,in_writestr_x];

        { if we fail, we can quickly exit this way. We must generate something }
        { instead of the inline node, because firstpass will bomb with an      }
        { internalerror if it encounters a read/write                          }
        result := CErrorNode.create;

        { reverse the parameters (needed to get the colon parameters in the }
        { correct order when processing write(ln)                           }
        reverseparameters(TCallParaNode(left));

        if is_rwstr then
          begin
            filepara := TCallParaNode(left);
            { needs at least two parameters: source/dest string + min. 1 value }
            if not(Assigned(filepara)) or
               not(Assigned(filepara.right)) then
              begin
                CGMessagePos1(fileinfo,parser_e_wrong_parameter_size,'ReadStr/WriteStr');
                exit;
              end
            else if (filepara.resultdef.typ <> stringdef) then
              begin
                { convert chararray to string, or give an appropriate error message }
                { (if you want to optimize to use shortstring, keep in mind that    }
                {  readstr internally always uses ansistring, and to account for    }
                {  chararrays with > 255 characters)                                }
                inserttypeconv(filepara.left,GetAnsiStringDef);
                filepara.resultdef:=filepara.left.resultdef;
                if CodeGenError then
                  exit;
              end
          end
        else if Assigned(left) then
          begin
            { check if we have a file parameter and if yes, what kind it is }
            filepara := TCallParaNode(left);

            if (filepara.resultdef.typ=filedef) then
              begin
                if (TFileDef(filepara.resultdef).FileTyp=ft_untyped) then
                  begin
                    CGMessagePos(fileinfo,type_e_no_read_write_for_untyped_file);
                    exit;
                  end
                else
                  begin
                    if (TFileDef(filepara.resultdef).FileTyp=ft_typed) then
                      begin
                        if (inlinenumber in [in_readln_x,in_writeln_x]) then
                          begin
                            CGMessagePos(fileinfo,type_e_no_readln_writeln_for_typed_file);
                            exit;
                          end;
                        is_typed := true;
                      end
                  end;
              end
            else
              filepara := nil;
          end;

        if Assigned(filepara) and
            Assigned(filepara.right) and
            (cpf_is_colon_para in TCallParaNode(filepara.right).callparaflags) then
          begin
            CGMessagePos(filepara.fileinfo,parser_e_illegal_colon_qualifier);
            { for recovery we can simply continue, because the compiler will
              simply treat the next parameters as normal parameters }
          end;

        { create a blocknode in which the successive write/read statements will be  }
        { put, since they belong together. Also create a dummy statement already to }
        { make inserting of additional statements easier                            }
        newblock:=internalstatements(newstatement);

        if is_rwstr then
          begin
            { create a dummy temp text file that will be used to cache the
              readstr/writestr state. Can't use a global variable in the system
              unit because these can be nested (in case of parameters to
              writestr that are function calls to functions that also call
              readstr/writestr) }
            textsym:=Search_System_Type('TEXT');
            filetemp:=CTempCreateNode.create(textsym.typedef,textsym.typedef.Size,tt_persistent,false);
            addstatement(newstatement,filetemp);

            if (do_read) then
              name:='fpc_setupreadstr_'
            else
              name:='fpc_setupwritestr_';
            name:=name+TStringDef(filepara.resultdef).StringTypName;
            { the file para is a var parameter, but it is properly initialized,
              so it should be actually an out parameter }
            if not(do_read) then
              set_varstate(filepara.left,vs_written,[]);
            { remove the source/destination string parameter from the }
            { parameter chain                                         }
            left:=filepara.right;
            filepara.right:=CCallParaNode.create(CTempRefNode.create(filetemp),nil);
            { in case of a writestr() to an ansistring, also pass the string's
              code page }
            if not do_read and
               Is_AnsiString(filepara.left.resultdef) then
              filepara:=CCallParaNode.create(genintconstnode(TStringDef(filepara.left.resultdef).encoding),filepara);
            { pass the temp text file and the source/destination string to the
              setup routine, which will store the string's address in the
              textrec }
            addstatement(newstatement,CCallNode.createintern(name,filepara));
            filepara:=CCallParaNode.create(CTempRefNode.create(filetemp),nil);
          end
        { if we don't have a filepara, create one containing the default }
        else if not Assigned(filepara) then
          begin
            { since the input/output variables are threadvars loading them into
              a temp once is faster. Create a temp which will hold a pointer to the file }
            filetemp := CTempCreateNode.create(VoidPointerType,VoidPointerType.Size,tt_persistent,true);
            addstatement(newstatement,filetemp);

            { make sure the resultdef of the temp (and as such of the }
            { temprefs coming after it) is set (necessary because the  }
            { temprefs will be part of the filepara, of which we need  }
            { the resultdef later on and temprefs can only be         }
            { typecheckpassed if the resultdef of the temp is known) }
            TypeCheckPass(TNode(filetemp));

            { assign the address of the file to the temp }
            if do_read then
              name := 'input'
            else
              name := 'output';
            addstatement(newstatement,
              CAssignmentNode.create(CTempRefNode.create(filetemp),
                CCallNode.createintern('fpc_get_'+name,nil)));

            { create a new fileparameter as follows: file_type(temp^)    }
            { (so that we pass the value and not the address of the temp }
            { to the read/write routine)                                 }
            textsym:=Search_System_Type('TEXT');
            filepara := CCallParaNode.create(CTypeConvNode.Create_Internal(
              CDerefNode.create(CTempRefNode.create(filetemp)),textsym.typedef),nil);
          end
        else
          { remove filepara from the parameter chain }
          begin
            left := filepara.right;
            filepara.right := nil;
            { the file para is a var parameter, but it must be valid already }
            set_varstate(filepara.left,vs_readwritten,[vsf_must_be_valid]);
            { check if we should make a temp to store the result of a complex }
            { expression (better heuristics, anyone?) (JM)                    }
            if (filepara.left.nodetype <> loadn) then
              begin
                { create a temp which will hold a pointer to the file }
                filetemp := CTempCreateNode.create(VoidPointerType,VoidPointerType.Size,tt_persistent,true);

                { add it to the statements }
                addstatement(newstatement,filetemp);

                { make sure the resultdef of the temp (and as such of the }
                { temprefs coming after it) is set (necessary because the  }
                { temprefs will be part of the filepara, of which we need  }
                { the resultdef later on and temprefs can only be         }
                { typecheckpassed if the resultdef of the temp is known) }
                TypeCheckPass(TNode(filetemp));

                { assign the address of the file to the temp }
                addstatement(newstatement,
                  CAssignmentNode.create(CTempRefNode.create(filetemp),
                    CAddrNode.Create_Internal(filepara.left)));
                TypeCheckPass(newstatement.left);
                { create a new fileparameter as follows: file_type(temp^)    }
                { (so that we pass the value and not the address of the temp }
                { to the read/write routine)                                 }
                nextpara := CCallParaNode.create(CTypeConvNode.Create_Internal(
                  CDerefNode.create(CTempRefNode.create(filetemp)),filepara.left.resultdef),nil);

                { replace the old file para with the new one }
                filepara.left := nil;
                filepara.free;
                filepara := nextpara;
              end;
          end;

        { the resultdef of the filepara must be set since it's }
        { used below                                            }
        filepara.get_paratype;

        { now, filepara is nowhere referenced anymore, so we can safely dispose it }
        { if something goes wrong or at the end of the procedure                   }

        { we're going to reuse the paranodes, so make sure they don't get freed }
        { twice                                                                 }
        params:=TCallParaNode(left);
        left := nil;

        if is_typed then
          found_error:=handle_typed_read_write(filepara,TTertiaryNode(params),TNode(newstatement))
        else
          found_error:=handle_text_read_write(filepara,TTertiaryNode(params),TNode(newstatement));

        { free the file parameter (it's copied inside the handle_*_read_write methods) }
        filepara.free;
        filepara := nil;

        { if we found an error, simply delete the generated blocknode }
        if found_error then
          begin
            { ensure that the tempinfo is freed correctly by destroying a
              delete node for it
              Note: this might happen legitimately when parsing a generic that
                    passes an undefined type to Write/Read }
            if Assigned(filetemp) then
              CTempDeleteNode.create(filetemp).free; // no nil needed
            newblock.free;
            newblock := nil;
          end
        else
          begin
            { deallocate the temp for the file para if we used one }
            if Assigned(filetemp) then
              addstatement(newstatement,CTempDeleteNode.create(filetemp));
            { otherwise return the newly generated block of instructions, }
            { but first free the errornode we generated at the beginning }
            result.free;
            result := newblock
          end;
      end;


    function get_val_int_func(def: TDef): string;
    var
      OrdType: TOrdType;
    begin
      OrdType := TOrdDef(def).OrdType;
      if not (OrdType in [s64bit,u64bit,s32bit,u32bit,s16bit,u16bit,s8bit,u8bit]) then
        InternalError(2020080101);

      if Is_OversizedInt(def) then
        begin
          case OrdType of
            s64bit: exit('int64');
            u64bit: exit('qword');
            s32bit: exit('longint');
            u32bit: exit('longword');
            s16bit: exit('smallint');
            u16bit: exit('word');
            else
              InternalError(2013032606);
          end;
        end
      else
        begin
          case OrdType of
            s64bit,s32bit,s16bit,s8bit: exit('sint');
            u64bit,u32bit,u16bit,u8bit: exit('uint');
            else
              InternalError(2013032607);
          end;
        end;
      InternalError(2013032608);
    end;


    function TInlineNode.handle_val: TNode;
      var
        procname,
        suffix        : string[31];
        sourcepara,
        destpara,
        codepara,
        sizepara,
        newparas      : TCallParaNode;
        orgcode,tc    : TNode;
        newstatement  : TStatementNode;
        newblock      : TBlockNode;
        tempcode      : TTempCreateNode;
        valsinttype   : TDef;
      begin
        { for easy exiting if something goes wrong }
        result := CErrorNode.create;

        { check the amount of parameters }
        if not(Assigned(left)) or
           not(Assigned(TCallParaNode(left).right)) then
         begin
           CGMessage1(parser_e_wrong_parameter_size,'Val');
           exit;
         end;

         suffix:='';

         { in case we are in a generic definition, we cannot
           do all checks, the parameters might be type parameters }
         if df_generic in CurrentProcInfo.procdef.DefOptions then
           begin
             result.Free;
             result:=nil;
             resultdef:=VoidType;
             exit;
           end;

        { retrieve the ValSInt type }
        valsinttype:=Search_System_Type('VALSINT').typedef;

        { reverse parameters for easier processing }
        reverseparameters(TCallParaNode(left));

        { get the parameters }
        tempcode := nil;
        orgcode := nil;
        sizepara := nil;
        sourcepara := TCallParaNode(left);
        destpara := TCallParaNode(sourcepara.right);
        codepara := TCallParaNode(destpara.right);

        { check if codepara is valid }
        if Assigned(codepara) and
           (
            not Is_Integer(codepara.resultdef)
{$ifndef cpu64bitaddr}
            or Is_64BitInt(codepara.resultdef)
{$endif not cpu64bitaddr}
            ) then
          begin
            CGMessagePos1(codepara.fileinfo,type_e_integer_expr_expected,codepara.resultdef.TypeName);
            exit;
          end;

        { check if dest para is valid }
        if not Is_Integer(destpara.resultdef) and
           not Is_Currency(destpara.resultdef) and
           not(destpara.resultdef.typ in [floatdef,enumdef]) then
          begin
            CGMessagePos(destpara.fileinfo,type_e_integer_or_real_expr_expected);
            exit;
          end;

        { we're going to reuse the existing para's, so make sure they  }
        { won't be disposed                                            }
        left := nil;

        { create the blocknode which will hold the generated statements + }
        { an initial dummy statement                                      }

        newblock:=internalstatements(newstatement);

        { do we need a temp for code? Yes, if no code specified, or if  }
        { code is not a valsinttype sized parameter (we already checked }
        { whether the code para, if specified, was an orddef)           }
        if not Assigned(codepara) or
           (codepara.resultdef.Size<>valsinttype.Size) then
          begin
            tempcode := CTempCreateNode.create(valsinttype,valsinttype.Size,tt_persistent,false);
            addstatement(newstatement,tempcode);
            { set the resultdef of the temp (needed to be able to get }
            { the resultdef of the tempref used in the new code para) }
            TypeCheckPass(TNode(tempcode));
            { create a temp codepara, but save the original code para to }
            { assign the result to later on                              }
            if Assigned(codepara) then
              begin
                orgcode := codepara.left;
                codepara.left := CTempRefNode.create(tempcode);
              end
            else
              codepara := CCallParaNode.create(CTempRefNode.create(tempcode),nil);
            { we need its resultdef later on }
            codepara.get_paratype;
          end
        else if (TOrdDef(codepara.resultdef).OrdType <> TOrdDef(valsinttype).OrdType) then
          { because code is a var parameter, it must match types exactly    }
          { however, since it will return values >= 0, both signed and      }
          { and unsigned ints of the same size are fine. Since the formal   }
          { code para type is sinttype, insert a typecoversion to sint for  }
          { unsigned para's  }
          begin
            codepara.left := CTypeConvNode.Create_Internal(codepara.left,valsinttype);
            { make it explicit, otherwise you may get a nonsense range}
            { check error if the cardinal already contained a value   }
            { > $7fffffff                                             }
            codepara.get_paratype;
          end;

        { create the procedure name }
        procname := 'fpc_val_';

        case destpara.resultdef.typ of
          orddef:
            begin
              case TOrdDef(destpara.resultdef).OrdType of
                s8bit,s16bit,s32bit,s64bit,
                u8bit,u16bit,u32bit,u64bit:
                  begin
                    suffix := get_val_int_func(destpara.resultdef) + '_';
                    { we also need a destsize para in the case of sint or uint }
                    if (suffix = 'sint_') or (suffix = 'uint_') then
                      sizepara := CCallParaNode.create(COrdConstNode.create
                        (destpara.resultdef.Size,S32IntType,true),nil);
                  end;
                scurrency: suffix := 'currency_';
                else
                  InternalError(200304225);
              end;
            end;
          floatdef:
            suffix:='real_';
          enumdef:
            begin
              suffix:='enum_';
              sizepara:=CCallParaNode.create(CAddrNode.Create_Internal(
                CRTTINode.create(TEnumDef(destpara.resultdef),fullrtti,rdt_str2ord)
              ),nil);
            end;
          else
            InternalError(2019050515);
        end;

        procname := procname + suffix;

        { play a trick to have tcallnode handle invalid source parameters: }
        { the shortstring-longint val routine by default                   }
        if (sourcepara.resultdef.typ = stringdef) then
          procname := procname + TStringDef(sourcepara.resultdef).StringTypName
        { zero-based arrays (of char) can be implicitly converted to ansistring, but don't do
          so if not needed because the array is too short }
        else if Is_Zero_Based_Array(sourcepara.resultdef) and (sourcepara.resultdef.Size>255) then
          procname := procname + 'ansistr'
        else
          procname := procname + 'shortstr';

        { set up the correct parameters for the call: the code para... }
        newparas := codepara;
        { and the source para }
        codepara.right := sourcepara;
        { sizepara either contains nil if none is needed (which is ok, since   }
        { then the next statement serves any possible links with other paras   }
        { that sourcepara may have) or it contains the necessary size para and }
        { its right field is nil                                               }
        sourcepara.right := sizepara;

        { create the call and assign the result to dest (val helpers are functions).
          Use a trick to prevent a type size mismatch warning to be generated by the
          assignment node. First convert implicitly to the resultdef. This will insert
          the range check. The Second conversion is done explicitly to hide the implicit conversion
          for the assignment node and therefor preventing the warning (PFV)

          The implicit conversion is avoided for enums because implicit conversion between
          longint (which is what fpc_val_enum_shortstr returns) and enumerations is not
          possible. (DM).

          The implicit conversion is also avoided for COMP type if it is handled by FPU (x86)
          to prevent warning about automatic type conversion. }
        if (destpara.resultdef.typ=enumdef) or
           ((destpara.resultdef.typ=floatdef) and (TFloatDef(destpara.resultdef).FloatType=s64comp))
          then
            tc:=CCallNode.createfromintrinsic(in_val_x,procname,newparas)
        else
          tc:=CTypeConvNode.create(CCallNode.createfromintrinsic(in_val_x,procname,newparas),destpara.left.resultdef);
        addstatement(newstatement,CAssignmentNode.create(
          destpara.left,CTypeConvNode.Create_Internal(tc,destpara.left.resultdef)));

        { dispose of the enclosing paranode of the destination }
        destpara.left := nil;
        destpara.right := nil;
        destpara.free;
        destpara := nil;

        { check if we used a temp for code and whether we have to store }
        { it to the real code parameter                                 }
        if Assigned(orgcode) then
          addstatement(newstatement,CAssignmentNode.create(
              orgcode,
              CTypeConvNode.Create_Internal(
                CTempRefNode.create(tempcode),orgcode.resultdef)));

        { release the temp if we allocated one }
        if Assigned(tempcode) then
          addstatement(newstatement,CTempDeleteNode.create(tempcode));

        { free the errornode }
        result.free;
        { and return it }
        result := newblock;
      end;

    function TInlineNode.handle_setlength: TNode;
      var
        def: TDef;
        destppn,
        paras: TNode;
        newstatement: TStatementNode;
        ppn: TCallParaNode;
        counter,
        dims: LongInt;
        isarray: boolean;
      begin
        { for easy exiting if something goes wrong }
        result:=CErrorNode.create;
        resultdef:=VoidType;
        paras:=left;
        dims:=0;
        if Assigned(paras) then
         begin
           { check type of lengths }
           ppn:=TCallParaNode(paras);
           while Assigned(ppn.right) do
            begin
              set_varstate(ppn.left,vs_read,[vsf_must_be_valid]);
              inserttypeconv(ppn.left,SIntType);
              inc(dims);
              ppn:=TCallParaNode(ppn.right);
            end;
         end
        else
         InternalError(2013112912);
        if dims=0 then
         begin
           CGMessage1(parser_e_wrong_parameter_size,'SetLength');
           exit;
         end;
        { last param must be var }
        destppn:=ppn.left;
        valid_for_var(destppn,true);
        set_varstate(destppn,vs_written,[vsf_must_be_valid,vsf_use_hints,vsf_use_hint_for_string_result]);
        { first param must be a string or dynamic array ...}
        isarray:=Is_Dynamic_Array(destppn.resultdef);
        if not((destppn.resultdef.typ=stringdef) or
               isarray) then
          begin
            { possibly generic involved? }
            if df_generic in CurrentProcInfo.procdef.DefOptions then
              result:=internalstatements(newstatement)
            else
              CGMessage(type_e_mismatch);
            exit;
          end;

        { only dynamic arrays accept more dimensions }
        if (dims>1) then
         begin
           if (not isarray) then
            CGMessage(type_e_mismatch)
           else
            begin
              { check if the amount of dimensions is valid }
              def:=TArrayDef(destppn.resultdef).ElementDef;
              counter:=dims;
              while counter > 1 do
                begin
                  if not(Is_Dynamic_Array(def)) then
                    begin
                      CGMessage1(parser_e_wrong_parameter_size,'SetLength');
                      break;
                    end;
                  dec(counter);
                  def:=TArrayDef(def).ElementDef;
                end;
            end;
         end;
        result.free;
        result:=nil;
      end;


    function TInlineNode.handle_copy: TNode;

      procedure do_error(typemismatch:boolean;func:string;fi:TFilePosInfo);

        procedure write_dynarray_copy;
          begin
            MessagePos1(fileinfo,sym_e_param_list,'Copy(Dynamic Array;'+SizeSIntType.TypeName+'=`<low>`;'+SizeSIntType.TypeName+'=`<length>`);');
          end;

        begin
          if typemismatch then
            CGMessagePos(fi,type_e_mismatch)
          else
            CGMessagePos1(fi,parser_e_wrong_parameter_size,'Copy');
          if func='' then
            begin
              Write_System_Parameter_Lists('fpc_shortstr_copy');
              Write_System_Parameter_Lists('fpc_char_copy');
              Write_System_Parameter_Lists('fpc_unicodestr_copy');
              if tf_winlikewidestring in TargetInfo.flags then
                Write_System_Parameter_Lists('fpc_widestr_copy');
              Write_System_Parameter_Lists('fpc_ansistr_copy');
              write_dynarray_copy;
            end
          else if func='fpc_dynarray_copy' then
            write_dynarray_copy
          else
            Write_System_Parameter_Lists(func);
        end;

      var
        paras   : TNode;
        ppn     : TCallParaNode;
        paradef : TDef;
        counter : integer;
        minargs,
        maxargs : LongInt;
        func : string;
      begin
        if not Assigned(left) then
          begin
            do_error(false,'',fileinfo);
            exit(CErrorNode.create);
          end;
        result:=nil;
        { determine copy function to use based on the first argument,
          also count the number of arguments in this loop }
        counter:=1;
        paras:=left;
        ppn:=TCallParaNode(paras);
        while Assigned(ppn.right) do
         begin
           inc(counter);
           set_varstate(ppn.left,vs_read,[vsf_must_be_valid]);
           ppn:=TCallParaNode(ppn.right);
         end;
        set_varstate(ppn.left,vs_read,[vsf_must_be_valid]);
        paradef:=ppn.left.resultdef;
        { the string variants all require 2 or 3 args, only the array one allows less }
        minargs:=2;
        maxargs:=3;
        func:='';
        if Is_AnsiString(paradef) then
          begin
            // set resultdef to argument def
            resultdef:=paradef;
            func:='fpc_ansistr_copy';
          end
        else if (Is_CharArray(paradef) and (paradef.Size>255)) or
           ((cs_refcountedstrings in CurrentSettings.LocalSwitches) and Is_PChar(paradef)) then
          begin
            // set resultdef to ansistring type since result will be in ansistring codepage
            resultdef:=GetAnsiStringDef;
            func:='fpc_ansistr_copy';
          end
        else if Is_WideString(paradef) then
          begin
           resultdef:=CWideStringType;
           func:='fpc_widestr_copy';
          end
        else if Is_UnicodeString(paradef) or
            Is_WideCharArray(paradef) or
            Is_PWideChar(paradef) then
          begin
            resultdef:=CUnicodeStringType;
            func:='fpc_unicodestr_copy';
          end
        else
         if Is_Char(paradef) then
           begin
             resultdef:=CShortStringType;
             func:='fpc_char_copy';
           end
        else
         if Is_Dynamic_Array(paradef) then
          begin
            minargs:=1;
            resultdef:=paradef;
            func:='fpc_array_to_dynarray_copy';
          end
        else
         if Is_Open_Array(paradef) then
          begin
            minargs:=1;
            resultdef:=CArrayDef.create(0,-1,TArrayDef(paradef).RangeDef);
            TArrayDef(resultdef).ArrayOptions:=TArrayDef(resultdef).ArrayOptions+[ado_IsDynamicArray];
            TArrayDef(resultdef).ElementDef:=TArrayDef(paradef).ElementDef;
            func:='fpc_array_to_dynarray_copy';
          end
        else if counter in [2..3] then
          begin
            resultdef:=CShortStringType;
            func:='fpc_shortstr_copy';
          end
        else if counter<=maxargs then
          begin
            do_error(true,'',ppn.left.fileinfo);
            exit(CErrorNode.create);
          end;

        if (counter<minargs) or (counter>maxargs) then
          begin
            do_error(false,func,fileinfo);
            exit(CErrorNode.create);
          end;
      end;

{$maxfpuregisters 0}

    function TInlineNode.simplify(forinline : boolean): TNode;

      function do_lowhigh(def:TDef) : TNode;
        var
           v    : TConstExprInt;
           enum : TEnumSym;
           hp   : TNode;
           i    : integer;
        begin
           case def.typ of
             orddef:
               begin
                  set_varstate(left,vs_read,[]);
                  if inlinenumber=in_low_x then
                    v:=TOrdDef(def).low
                  else
                    v:=TOrdDef(def).high;
                  hp:=COrdConstNode.create(v,def,true);
                  TypeCheckPass(hp);
                  do_lowhigh:=hp;
               end;
             enumdef:
               begin
                  set_varstate(left,vs_read,[]);
                  if inlinenumber=in_high_x then
                    v:=TEnumDef(def).MaxVal
                  else
                    v:=TEnumDef(def).MinVal;
                  enum:=nil;
                  for i := 0 to TEnumDef(def).SymTable.SymList.Count - 1 do
                    if TEnumSym(TEnumDef(def).SymTable.SymList[i]).Value=v then
                      begin
                        enum:=TEnumSym(TEnumDef(def).SymTable.SymList[i]);
                        break;
                      end;
                  if not Assigned(enum) then
                    InternalError(309993)
                  else
                    hp:=genenumnode(enum);
                  do_lowhigh:=hp;
               end;
           else
             InternalError(87);
           end;
        end;


      function getconstrealvalue : BestReal;
        begin
           case left.nodetype of
              ordconstn:
                getconstrealvalue:=TOrdConstNode(left).Value;
              realconstn:
                begin
                  if (nf_is_currency in TRealConstNode(left).flags) then
                    getconstrealvalue:=TRealConstNode(left).value_real/BestReal(10000.0)
                  else
                    getconstrealvalue:=TRealConstNode(left).value_real;
                end
              else
                InternalError(309992);
           end;
        end;


      procedure setconstrealvalue(r : BestReal);
        begin
           result:=CRealConstNode.create(r,PBestRealType^);
        end;


      function handle_ln_const(r : BestReal) : TNode;
        begin
          if r<=0.0 then
            if Floating_Point_Range_Check_Error then
               begin
                 result:=CRealConstNode.create(0,PBestRealType^);
                 CGMessage(type_e_wrong_math_argument)
               end
            else
              begin
                if r=0.0 then
                  result:=CRealConstNode.create(MathNegInf.Value,PBestRealType^)
                else
                  result:=CRealConstNode.create(MathQNaN.Value,PBestRealType^)
              end
          else
            result:=CRealConstNode.create(Ln(r),PBestRealType^)
        end;


      function handle_sqrt_const(r : BestReal) : TNode;
        begin
          if r<0.0 then
            if Floating_Point_Range_Check_Error then
               begin
                 result:=CRealConstNode.create(0,PBestRealType^);
                 CGMessage(type_e_wrong_math_argument)
               end
            else
              result:=CRealConstNode.create(MathQNaN.Value,PBestRealType^)
          else
            result:=CRealConstNode.create(Sqrt(r),PBestRealType^)
        end;


      function handle_const_sar : TNode;
        var
          vl,vl2    : TConstExprInt;
          bits,shift: integer;
          mask : qword;
          def : TDef;
        begin
          result:=nil;
          if (left.nodetype=ordconstn) or ((left.nodetype=callparan) and (TCallParaNode(left).left.nodetype=ordconstn)) then
            begin
              if (left.nodetype=callparan) and
                 Assigned(TCallParaNode(left).right) then
                begin
                  vl:=TOrdConstNode(TCallParaNode(left).left).Value;
                  if forinline then
                    case resultdef.Size of
                      1,2,4:
                        vl:=vl and byte($1f);
                      8:
                        vl:=vl and byte($3f);
                      else
                        InternalError(2013122303);
                    end;
                  if (TCallParaNode(TCallParaNode(left).right).left.nodetype=ordconstn) then
                    begin
                      def:=TCallParaNode(TCallParaNode(left).right).left.resultdef;
                      vl2:=TOrdConstNode(TCallParaNode(TCallParaNode(left).right).left).Value;
                    end
                  else if vl=0 then
                    begin
                      result:=TCallParaNode(TCallParaNode(left).right).left;
                      TCallParaNode(TCallParaNode(left).right).left:=nil;
                      exit;
                    end
                  else
                    exit;
                end
              else
                begin
                  def:=left.resultdef;
                  vl:=1;
                  vl2:=TOrdConstNode(left).Value;
                end;

              bits:=def.Size*8;
              shift:=vl.svalue and (bits-1);
              case bits of
                 8:
                   mask:=$ff;
                 16:
                   mask:=$ffff;
                 32:
                   mask:=$ffffffff;
                 64:
                   mask:=qword($ffffffffffffffff);
                 else
                   mask:=qword(1 shl bits)-1;
              end;
{$push}
{$r-,q-}
              if shift=0 then
                result:=COrdConstNode.create(vl2.svalue,def,false)
              else if vl2.svalue<0 then
                result:=COrdConstNode.create(((vl2.svalue shr shift) or (mask shl (bits-shift))) and mask,def,false)
              else
                result:=COrdConstNode.create((vl2.svalue shr shift) and mask,def,false);
{$pop}
            end
          else if (left.nodetype=callparan) and Assigned(TCallParaNode(left).right) and
                  (TCallParaNode(TCallParaNode(left).right).left.nodetype=ordconstn) then
            begin
              def:=TCallParaNode(TCallParaNode(left).right).left.resultdef;
              vl2:=TOrdConstNode(TCallParaNode(TCallParaNode(left).right).left).Value;
              { sar(0,x) is 0 }
              { sar32(ffffffff,x) is ffffffff, etc. }
              if ((vl2=0) or
                  ((resultdef.Size=1) and (shortint(vl2.svalue)=-1)) or
                  ((resultdef.Size=2) and (smallint(vl2.svalue)=-1)) or
                  ((resultdef.Size=4) and (LongInt(vl2.svalue)=-1)) or
                  ((resultdef.Size=8) and (int64(vl2.svalue)=-1))) and
                 ((cs_opt_level4 in CurrentSettings.OptimizerSwitches) or
                  not might_have_sideeffects(TCallParaNode(left).left)) then
                begin
                  if vl2=0 then
                    result:=COrdConstNode.create(0,resultdef,true)
                  else
                    result:=COrdConstNode.create(-1,resultdef,true);
                end;
            end;
        end;


      function handle_const_rox : TNode;
        var
          vl,vl2    : TConstExprInt;
          bits,shift: integer;
          def : TDef;
        begin
          result:=nil;
          if (left.nodetype=ordconstn) or ((left.nodetype=callparan) and (TCallParaNode(left).left.nodetype=ordconstn)) then
            begin
              if (left.nodetype=callparan) and
                 Assigned(TCallParaNode(left).right) then
                begin
                  vl:=TOrdConstNode(TCallParaNode(left).left).Value;
                  if forinline then
                    case resultdef.Size of
                      { unlike shifts, for rotates, when masking out the higher bits
                        of the rotate count, we go all the way down to byte, because
                        it doesn't matter, it produces the same result, since it's a rotate }
                      1:
                        vl:=vl and byte($07);
                      2:
                        vl:=vl and byte($0f);
                      4:
                        vl:=vl and byte($1f);
                      8:
                        vl:=vl and byte($3f);
                      else
                        InternalError(2013122304);
                    end;
                  if (TCallParaNode(TCallParaNode(left).right).left.nodetype=ordconstn) then
                    begin
                      def:=TCallParaNode(TCallParaNode(left).right).left.resultdef;
                      vl2:=TOrdConstNode(TCallParaNode(TCallParaNode(left).right).left).Value;
                    end
                  else if vl=0 then
                    begin
                      result:=TCallParaNode(TCallParaNode(left).right).left;
                      TCallParaNode(TCallParaNode(left).right).left:=nil;
                      exit;
                    end
                  else
                    exit;
                end
              else
                begin
                  def:=left.resultdef;
                  vl:=1;
                  vl2:=TOrdConstNode(left).Value;
                end;

              bits:=def.Size*8;
              shift:=vl.svalue and (bits-1);
{$push}
{$r-,q-}
              if shift=0 then
                result:=COrdConstNode.create(vl2.svalue,def,false)
              else
                case inlinenumber of
                  in_ror_x,in_ror_x_y:
                    case def.Size of
                      1:
                        result:=COrdConstNode.create(RorByte(Byte(vl2.svalue),shift),def,false);
                      2:
                        result:=COrdConstNode.create(RorWord(Word(vl2.svalue),shift),def,false);
                      4:
                        result:=COrdConstNode.create(RorDWord(DWord(vl2.svalue),shift),def,false);
                      8:
                        result:=COrdConstNode.create(RorQWord(QWord(vl2.svalue),shift),def,false);
                      else
                        InternalError(2011061903);
                    end;
                  in_rol_x,in_rol_x_y:
                    case def.Size of
                      1:
                        result:=COrdConstNode.create(RolByte(Byte(vl2.svalue),shift),def,false);
                      2:
                        result:=COrdConstNode.create(RolWord(Word(vl2.svalue),shift),def,false);
                      4:
                        result:=COrdConstNode.create(RolDWord(DWord(vl2.svalue),shift),def,false);
                      8:
                        result:=COrdConstNode.create(RolQWord(QWord(vl2.svalue),shift),def,false);
                      else
                        InternalError(2011061902);
                    end;
                  else
                    InternalError(2011061901);
                  end;
{$pop}
            end
          else if (left.nodetype=callparan) and Assigned(TCallParaNode(left).right) and
                  (TCallParaNode(TCallParaNode(left).right).left.nodetype=ordconstn) then
            begin
              def:=TCallParaNode(TCallParaNode(left).right).left.resultdef;
              vl2:=TOrdConstNode(TCallParaNode(TCallParaNode(left).right).left).Value;
              { rol/ror are unsigned operations, so cut off upper bits }
              case resultdef.Size of
                1:
                  vl2:=vl2 and byte($ff);
                2:
                  vl2:=vl2 and word($ffff);
                4:
                  vl2:=vl2 and dword($ffffffff);
                8:
                  vl2:=vl2 and qword($ffffffffffffffff);
                else
                  InternalError(2017050101);
              end;
              { rol(0,x) and ror(0,x) are 0 }
              { rol32(ffffffff,x) and ror32(ffffffff,x) are ffffffff, etc. }
              if ((vl2=0) or
                  ((resultdef.Size=1) and (vl2=$ff)) or
                  ((resultdef.Size=2) and (vl2=$ffff)) or
                  ((resultdef.Size=4) and (vl2=$ffffffff)) or
                  ((resultdef.Size=8) and (vl2.uvalue=qword($ffffffffffffffff)))) and
                 ((cs_opt_level4 in CurrentSettings.OptimizerSwitches) or
                  not might_have_sideeffects(TCallParaNode(left).left)) then
                result:=COrdConstNode.create(vl2,resultdef,true);
            end;
        end;

      function is_minmax_deterministic(var node: TOrdConstNode; const DoMax: Boolean; out res: Boolean): Boolean;
        begin
          Result := False;
          if not Is_Integer(resultdef) then
            InternalError(2024031501);

          if (node.Value <= TOrdDef(resultdef).low) then
            begin
              res := not DoMax;
              Exit(True);
            end
          else if (node.Value >= TOrdDef(resultdef).high) then
            begin
              res := DoMax;
              Exit(True);
            end
        end;

      var
        hp,hp2    : TNode;
        vl,vl2    : TConstExprInt;
        vr        : BestReal;
        helperres : Boolean;

      begin { simplify }
         result:=nil;
         { handle intern constant functions in separate case }
         if inf_inlineconst in inlinenodeflags then
          begin
            { no parameters? }
            if not Assigned(left) then
              InternalError(200501231)
            else
             begin
               vl:=0;
               vl2:=0; { second parameter Ex: ptr(vl,vl2) }
               case left.nodetype of
                 ordconstn :
                   vl:=TOrdConstNode(left).Value;
                 callparan :
                   begin
                     { both exists, else it was not generated }
                     vl:=TOrdConstNode(TCallParaNode(left).left).Value;
                     vl2:=TOrdConstNode(TCallParaNode(TCallParaNode(left).right).left).Value;
                   end;
                 else
                   begin
                     { Real functions are all handled with internproc below, and
                       unsupported typex are also trapped here }
                     if Is_Integer(left.resultdef) then
                       { Not as informative, but less confusing }
                       CGMessagePos(left.fileinfo,parser_e_illegal_expression)
                     else
                       CGMessagePos1(left.fileinfo,type_e_integer_expr_expected,left.resultdef.TypeName);
                     result:=CErrorNode.create;
                     exit;
                   end;
               end;
               case inlinenumber of
                 in_const_abs :
                   if vl.signed then
                     hp:=create_simplified_ord_const(abs(vl.svalue),resultdef,forinline,false)
                   else
                     hp:=create_simplified_ord_const(vl.uvalue,resultdef,forinline,false);
                 in_const_sqr:
                   if vl.signed then
                     hp:=create_simplified_ord_const(sqr(vl.svalue),resultdef,forinline,false)
                   else
                     hp:=create_simplified_ord_const(sqr(vl.uvalue),resultdef,forinline,false);
                 in_const_odd :
                   hp:=COrdConstNode.create(qword(odd(int64(vl))),PasBool1Type,true);
                 in_const_swap_word :
                   hp:=COrdConstNode.create((vl and $ff) shl 8+(vl shr 8),left.resultdef,true);
                 in_const_swap_long :
                   hp:=COrdConstNode.create((vl and $ffff) shl 16+(vl shr 16),left.resultdef,true);
                 in_const_swap_qword :
                   hp:=COrdConstNode.create((vl and $ffffffff) shl 32+(vl shr 32),left.resultdef,true);
                 in_const_ptr:
                   begin
                     {Don't construct pointers from negative values.}
                     if (vl.signed and (vl.svalue<0)) or (vl2.signed and (vl2.svalue<0)) then
                       CGMessage(parser_e_range_check_error);
{$if defined(i386)}
                     hp:=CPointerConstNode.create((vl2.uvalue shl 4)+vl.uvalue,VoidNearFSPointerType);
{$else}
                     hp:=CPointerConstNode.create((vl2.uvalue shl 4)+vl.uvalue,VoidPointerType);
{$endif}
                   end;
                 in_const_eh_return_data_regno:
                   begin
                     vl:=eh_return_data_regno(vl.svalue);
                     if vl=-1 then
                       CGMessagePos(left.fileinfo,type_e_range_check_error_bounds);
                     hp:=genintconstnode(vl);
                   end;
                 else
                   InternalError(88);
               end;
             end;
            if hp=nil then
              hp:=CErrorNode.create;
            result:=hp;
          end
        else
          begin
            case inlinenumber of
              in_lo_long,
              in_hi_long,
              in_lo_qword,
              in_hi_qword,
              in_lo_word,
              in_hi_word :
                begin
                  if left.nodetype=ordconstn then
                    begin
                      case inlinenumber of
                        in_lo_word :
                          result:=COrdConstNode.create(TOrdConstNode(left).Value and $ff,U8IntType,true);
                        in_hi_word :
                          result:=COrdConstNode.create(TOrdConstNode(left).Value shr 8,U8IntType,true);
                        in_lo_long :
                          result:=COrdConstNode.create(TOrdConstNode(left).Value and $ffff,U16IntType,true);
                        in_hi_long :
                          result:=COrdConstNode.create(TOrdConstNode(left).Value shr 16,U16IntType,true);
                        in_lo_qword :
                          result:=COrdConstNode.create(TOrdConstNode(left).Value and $ffffffff,U32IntType,true);
                        in_hi_qword :
                          result:=COrdConstNode.create(TOrdConstNode(left).Value shr 32,U32IntType,true);
                        else
                          InternalError(2019050514);
                      end;
                    end;
                end;
              in_ord_x:
                begin
                  case left.resultdef.typ of
                    orddef :
                      begin
                        case TOrdDef(left.resultdef).OrdType of
                          pasbool1,
                          pasbool8,
                          uchar:
                            begin
                              { change to byte() }
                              result:=CTypeConvNode.Create_Internal(left,U8IntType);
                              left:=nil;
                            end;
                          pasbool16,
                          uwidechar :
                            begin
                              { change to word() }
                              result:=CTypeConvNode.Create_Internal(left,U16IntType);
                              left:=nil;
                            end;
                          pasbool32 :
                            begin
                              { change to dword() }
                              result:=CTypeConvNode.Create_Internal(left,U32IntType);
                              left:=nil;
                            end;
                          pasbool64 :
                            begin
                              { change to qword() }
                              result:=CTypeConvNode.Create_Internal(left,U64IntType);
                              left:=nil;
                            end;
                          bool8bit:
                            begin
                              { change to shortint() }
                              result:=CTypeConvNode.Create_Internal(left,S8IntType);
                              left:=nil;
                            end;
                          bool16bit :
                            begin
                              { change to smallint() }
                              result:=CTypeConvNode.Create_Internal(left,S16IntType);
                              left:=nil;
                            end;
                          bool32bit :
                            begin
                              { change to longint() }
                              result:=CTypeConvNode.Create_Internal(left,S32IntType);
                              left:=nil;
                            end;
                          bool64bit :
                            begin
                              { change to int64() }
                              result:=CTypeConvNode.Create_Internal(left,S64IntType);
                              left:=nil;
                            end;
                          uvoid :
                            CGMessage1(type_e_ordinal_expr_expected,left.resultdef.TypeName);
                          else
                            begin
                              { all other orddef need no transformation }
                              result:=left;
                              left:=nil;
                            end;
                        end;
                      end;
                    enumdef :
                      begin
                        result:=CTypeConvNode.Create_Internal(left,S32IntType);
                        left:=nil;
                      end;
                    undefineddef :
                      begin
                        { we just create a constant 0 here, that's marked as a
                          parameter }
                        result:=COrdConstNode.create(0,S32IntType,false);
                        include(result.flags,nf_generic_para);
                        left:=nil;
                      end;
                    pointerdef :
                      begin
                        if m_mac in CurrentSettings.ModeSwitches then
                          begin
                            result:=CTypeConvNode.Create_Internal(left,PtrUIntType);
                            left:=nil;
                          end
                      end;
                    else
                      InternalError(2019050513);
                  end;
(*
                  if (left.nodetype=ordconstn) then
                     begin
                       result:=cordconstnode.create(
                         tordconstnode(left).value,sinttype,true);
                     end
                   else if (m_mac in current_settings.modeswitches) and
                           (left.ndoetype=pointerconstn) then
                       result:=cordconstnode.create(
                         tpointerconstnode(left).value,ptruinttype,true);
*)
                end;
              in_chr_byte:
                begin
                   { convert to explicit char() }
                   result:=CTypeConvNode.Create_Internal(left,CAnsiCharType);
                   left:=nil;
                end;
              in_length_x:
                begin
                  case left.resultdef.typ of
                    stringdef :
                      begin
                        if (left.nodetype=stringconstn) then
                          begin
                            result:=COrdConstNode.create(
                              TStringConstNode(left).len,SIntType,true);
                          end;
                      end;
                    orddef :
                      begin
                        { length of char is always one }
                        if Is_Char(left.resultdef) or
                           Is_WideChar(left.resultdef) then
                         begin
                           result:=COrdConstNode.create(1,SIntType,false);
                         end
                      end;
                    arraydef :
                      begin
                        if (left.nodetype=stringconstn) then
                          begin
                            result:=COrdConstNode.create(
                              TStringConstNode(left).len,SIntType,true);
                          end
                        else if not Is_Open_Array(left.resultdef) and
                           not Is_Array_Of_Const(left.resultdef) and
                           not Is_Dynamic_Array(left.resultdef) then
                          result:=genintconstnode(TArrayDef(left.resultdef).HighRange-
                            TArrayDef(left.resultdef).LowRange+1,SizeSIntType);
                      end;
                    else
                      ;
                  end;
                end;
              in_assigned_x:
                begin
                  if is_constnode(TCallParaNode(left).left) or
                     (TCallParaNode(left).left.nodetype = pointerconstn) then
                    begin
                      { let an add node figure it out }
                      result:=CAddNode.create(unequaln,TCallParaNode(left).left,CNilNode.create);
                      TCallParaNode(left).left := nil;
                    end;
                end;
              in_pred_x,
              in_succ_x:
                begin
                  case left.nodetype of
                    ordconstn:
                      begin
                        if inlinenumber=in_succ_x then
                          vl:=TOrdConstNode(left).Value+1
                        else
                          vl:=TOrdConstNode(left).Value-1;
                        if Is_Integer(left.resultdef) then
                          { the type of the original integer constant is irrelevant,
                            it should be automatically adapted to the new value
                            (except when inlining) }
                          result:=create_simplified_ord_const(vl,resultdef,forinline,cs_check_range in LocalSwitches)
                        else
                          { check the range for enums, chars, booleans }
                          result:=COrdConstNode.create(vl,left.resultdef,not(nf_internal in flags));
                        result.flags:=result.flags+(flags*[nf_internal]);
                      end;
                    addn,
                    subn:
                      begin
                        { fold succ/pred in child add/sub nodes with a constant if possible:
                           - no overflow/range checking
                           - equal types
                        }
                        if ([cs_check_overflow,cs_check_range]*CurrentSettings.LocalSwitches)=[] then
                          begin
                            if inlinenumber=in_succ_x then
                              vl:=1
                            else
                              vl:=-1;
                            if (TAddNode(left).left.nodetype=ordconstn) and Equal_Defs(resultdef,TAddNode(left).left.resultdef) then
                              begin
                                TOrdConstNode(TAddNode(left).left).Value:=TOrdConstNode(TAddNode(left).left).Value+vl;
                                result:=left;
                                left:=nil;
                              end
                            else if (TAddNode(left).right.nodetype=ordconstn) and Equal_Defs(resultdef,TAddNode(left).right.resultdef) then
                              begin
                                if left.nodetype=subn then
                                  TOrdConstNode(TAddNode(left).right).Value:=TOrdConstNode(TAddNode(left).right).Value-vl
                                else
                                  TOrdConstNode(TAddNode(left).right).Value:=TOrdConstNode(TAddNode(left).right).Value+vl;
                                result:=left;
                                left:=nil;
                              end;
                          end;
                      end;
                    else
                      ;
                  end;
                end;
              in_low_x,
              in_high_x:
                begin
                  case left.resultdef.typ of
                    orddef,
                    enumdef:
                      begin
                        result:=do_lowhigh(left.resultdef);
                      end;
                    setdef:
                      begin
                        result:=do_lowhigh(TSetDef(left.resultdef).ElementDef);
                      end;
                    arraydef:
                      begin
                        if (inlinenumber=in_low_x) then
                          begin
                            result:=COrdConstNode.create(int64(TArrayDef(
                             left.resultdef).LowRange),TArrayDef(left.resultdef).RangeDef,true);
                          end
                        else if not Is_Open_Array(left.resultdef) and
                                not Is_Array_Of_Const(left.resultdef) and
                                not Is_Dynamic_Array(left.resultdef) then
                          result:=COrdConstNode.create(int64(TArrayDef(left.resultdef).HighRange),
                            TArrayDef(left.resultdef).RangeDef,true);
                      end;
                    stringdef:
                      begin
                        if inlinenumber=in_low_x then
                          begin
                            if Is_DynamicString(left.resultdef) and
                              not(cs_zerobasedstrings in CurrentSettings.LocalSwitches) then
                              result:=COrdConstNode.create(1,U8IntType,false)
                            else
                              result:=COrdConstNode.create(0,U8IntType,false);
                          end
                        else if not Is_DynamicString(left.resultdef) then
                          result:=COrdConstNode.create(TStringDef(left.resultdef).len,U8IntType,true)
                      end;
                    undefineddef:
                      begin
                        result:=COrdConstNode.create(0,U8IntType,false);
                      end;
                    errordef:
                      ;
                    else
                      InternalError(2019050512);
                  end;
                end;
              in_exp_real :
                begin
                  if left.nodetype in [ordconstn,realconstn] then
                    begin
                      result:=CRealConstNode.create(Exp(getconstrealvalue),PBestRealType^);
                      if (TRealConstNode(result).value_real=MathInf.Value) and
                         Floating_Point_Range_Check_Error then
                        begin
                          result:=CRealConstNode.create(0,PBestRealType^);
                          CGMessage(parser_e_range_check_error);
                        end;
                    end
                end;
              in_trunc_real :
                begin
                  if left.nodetype in [ordconstn,realconstn] then
                    begin
                      vr:=getconstrealvalue;
                      if (vr>=BestReal(QWord($8000000000000000))) or (vr<BestReal(Low(Int64))) then
                        begin
                          message3(type_e_range_check_error_bounds,RealToStr(vr),'-9223372036854775808.0','9223372036854775807.99..');
                          result:=COrdConstNode.create(1,S64IntType,false)
                        end
                      else
                        result:=COrdConstNode.create(Trunc(vr),S64IntType,true)
                    end
                end;
              in_round_real :
                begin
                  { can't evaluate while inlining, may depend on fpu setting }
                  if (not forinline) and
                     (left.nodetype in [ordconstn,realconstn]) then
                    begin
                      vr:=getconstrealvalue;
                      if (vr>=BestReal(High(Int64))+BestReal(0.5)) or (vr<BestReal(Low(Int64))) then
                        begin
                          message3(type_e_range_check_error_bounds,RealToStr(vr),'-9223372036854775808.49..','9223372036854775807.49..');
                          result:=COrdConstNode.create(1,S64IntType,false)
                        end
                      else
                        result:=COrdConstNode.create(Round(vr),S64IntType,true)
                    end
                end;
              in_frac_real :
                begin
                  if left.nodetype in [ordconstn,realconstn] then
                    setconstrealvalue(Frac(getconstrealvalue))
                end;
              in_int_real :
                begin
                  if left.nodetype in [ordconstn,realconstn] then
                    setconstrealvalue(Int(getconstrealvalue));
                end;
              in_pi_real :
                 begin
                   if Block_Type=bt_const then
                     setconstrealvalue(Pi)
                 end;
              in_cos_real :
                begin
                  if left.nodetype in [ordconstn,realconstn] then
                    setconstrealvalue(Cos(getconstrealvalue))
                end;
              in_sin_real :
                begin
                  if left.nodetype in [ordconstn,realconstn] then
                    setconstrealvalue(Sin(getconstrealvalue))
                end;
              in_arctan_real :
                begin
                  if left.nodetype in [ordconstn,realconstn] then
                    setconstrealvalue(ArcTan(getconstrealvalue))
                end;
              in_abs_real :
                begin
                  if left.nodetype in [ordconstn,realconstn] then
                    setconstrealvalue(Abs(getconstrealvalue))
                end;
              in_abs_long:
                begin
                  if left.nodetype=ordconstn then
                    begin
                      if TOrdConstNode(left).Value<0 then
                        result:=COrdConstNode.create((-TOrdConstNode(left).Value),resultdef,false)
                      else
                        result:=COrdConstNode.create((TOrdConstNode(left).Value),resultdef,false);
                    end
                end;
              in_sqr_real :
                begin
                  if left.nodetype in [ordconstn,realconstn] then
                    setconstrealvalue((getconstrealvalue*getconstrealvalue))
                end;
              in_sqrt_real :
                begin
                  if left.nodetype in [ordconstn,realconstn] then
                    result:=handle_sqrt_const(getconstrealvalue);
                end;
              in_ln_real :
                begin
                  if left.nodetype in [ordconstn,realconstn] then
                    result:=handle_ln_const(getconstrealvalue);
                end;
              in_assert_x_y :
                begin
                  if not(cs_do_assertion in CurrentSettings.LocalSwitches) then
                    { we need a valid node, so insert a nothingn }
                    result:=CNothingNode.create;
                end;
              in_sar_x,
              in_sar_x_y :
                begin
                  result:=handle_const_sar;
                end;
              in_rol_x,
              in_rol_x_y,
              in_ror_x,
              in_ror_x_y :
                result:=handle_const_rox;
              in_bsf_x:
                begin
                  if left.nodetype=ordconstn then
                    begin
                      case left.resultdef.Size of
                        1:
                          result:=COrdConstNode.create(BsfByte(Byte(TOrdConstNode(left).Value.uvalue)),resultdef,false);
                        2:
                          result:=COrdConstNode.create(BsfWord(Word(TOrdConstNode(left).Value.uvalue)),resultdef,false);
                        4:
                          result:=COrdConstNode.create(BsfDWord(DWord(TOrdConstNode(left).Value.uvalue)),resultdef,false);
                        8:
                          result:=COrdConstNode.create(BsfQWord(QWord(TOrdConstNode(left).Value.uvalue)),resultdef,false);
                        else
                          InternalError(2017042401);
                      end;
                    end;
                end;
              in_bsr_x :
                begin
                  if left.nodetype=ordconstn then
                    begin
                      case left.resultdef.Size of
                        1:
                          result:=COrdConstNode.create(BsrByte(Byte(TOrdConstNode(left).Value.uvalue)),resultdef,false);
                        2:
                          result:=COrdConstNode.create(BsrWord(Word(TOrdConstNode(left).Value.uvalue)),resultdef,false);
                        4:
                          result:=COrdConstNode.create(BsrDWord(DWord(TOrdConstNode(left).Value.uvalue)),resultdef,false);
                        8:
                          result:=COrdConstNode.create(BsrQWord(QWord(TOrdConstNode(left).Value.uvalue)),resultdef,false);
                        else
                          InternalError(2017042402);
                      end;
                    end;
                end;
              in_popcnt_x :
                begin
                  if left.nodetype=ordconstn then
                    begin
                      result:=COrdConstNode.create(PopCnt(TOrdConstNode(left).Value),resultdef,false);
                    end;
                end;
              in_min_single,
              in_min_double:
                begin
                  { Check to see if the result is deterministic }
                  if left.nodetype=callparan then
                    begin
                      hp:=TCallParaNode(TCallParaNode(left).nextpara).paravalue;
                      hp2:=TCallParaNode(left).paravalue;

                      if (hp.nodetype=realconstn) then
                        begin
                          if (TRealConstNode(hp).value_real = MathQNaN.Value) then
                            { If one of the inputs is NaN, the second parameter
                              is taken }
                            result:=hp2.GetCopy()
                          else if (TRealConstNode(hp).value_real = MathNegInf.Value) then
                            { Nothing is less than than -oo }
                            result:=CRealConstNode.create(MathNegInf.Value,resultdef)
                          else if (TRealConstNode(hp).value_real = MathInf.Value) then
                            { Everything is less than +oo }
                            result:=hp2.GetCopy()
                          else if (hp2.nodetype=realconstn) then
                            begin
                              { Both actual parameters are constants, so take
                                the smaller of the two right now }
                              if (TRealConstNode(hp).value_real < TRealConstNode(hp2).value_real) then
                                result:=CRealConstNode.create(TRealConstNode(hp).value_real,resultdef)
                              else
                                result:=CRealConstNode.create(TRealConstNode(hp2).value_real,resultdef);
                            end;
                        end
                      else if (hp2.nodetype=realconstn) then
                        begin
                          if (TRealConstNode(hp2).value_real = MathQNaN.Value) then
                            { If one of the inputs is NaN, the second parameter
                              is taken (even if it is NaN) }
                            result:=CRealConstNode.create(MathQNaN.Value,resultdef)
                          else if (TRealConstNode(hp2).value_real = MathNegInf.Value) then
                            { Nothing is less than than -oo }
                            result:=CRealConstNode.create(MathNegInf.Value,resultdef)
                          else if (TRealConstNode(hp2).value_real = MathInf.Value) then
                            { Everything is less than +oo }
                            result:=hp.GetCopy();
                        end;
                    end;
                end;
              in_max_single,
              in_max_double:
                begin
                  { Check to see if the result is deterministic }
                  if left.nodetype=callparan then
                    begin
                      hp:=TCallParaNode(TCallParaNode(left).nextpara).paravalue;
                      hp2:=TCallParaNode(left).paravalue;

                      if (hp.nodetype=realconstn) then
                        begin
                          if (TRealConstNode(hp).value_real = MathQNaN.Value) then
                            { If one of the inputs is NaN, the second parameter
                              is taken }
                            result:=hp2.GetCopy()
                          else if (TRealConstNode(hp).value_real = MathNegInf.Value) then
                            { Everything is greater than than -oo }
                            result:=hp2.GetCopy()
                          else if (TRealConstNode(hp).value_real = MathInf.Value) then
                            { Nothing is greater than +oo }
                            result:=CRealConstNode.create(MathInf.Value,resultdef)
                          else if (hp2.nodetype=realconstn) then
                            begin
                              { Both actual parameters are constants, so take
                                the larger of the two right now }
                              if (TRealConstNode(hp).value_real > TRealConstNode(hp2).value_real) then
                                result:=CRealConstNode.create(TRealConstNode(hp).value_real,resultdef)
                              else
                                result:=CRealConstNode.create(TRealConstNode(hp2).value_real,resultdef)
                            end;
                        end
                      else if (hp2.nodetype=realconstn) then
                        begin
                          if (TRealConstNode(hp2).value_real = MathQNaN.Value) then
                            { If one of the inputs is NaN, the second parameter
                              is taken (even if it is NaN) }
                            result:=CRealConstNode.create(MathQNaN.Value,resultdef)
                          else if (TRealConstNode(hp2).value_real = MathNegInf.Value) then
                            { Everything is greater than than -oo }
                            result:=hp.GetCopy()
                          else if (TRealConstNode(hp2).value_real = MathInf.Value) then
                            { Nothing is greater than +oo }
                            result:=CRealConstNode.create(MathInf.Value,resultdef);
                        end;
                    end;
                end;
              in_min_longint,
              in_min_int64:
                begin
                  if left.nodetype=callparan then
                    begin
                      { Check to see if the result is deterministic }
                      hp:=TCallParaNode(TCallParaNode(left).nextpara).paravalue;
                      hp2:=TCallParaNode(left).paravalue;

                      if (hp.nodetype=ordconstn) then
                        begin
                          if (hp2.nodetype=ordconstn) then
                            begin
                              { Both actual parameters are constants, so take
                                the smaller of the two right now }
                              if inlinenumber=in_min_longint then
                                result:=COrdConstNode.create(min(LongInt(TOrdConstNode(hp).Value.svalue),LongInt(TOrdConstNode(hp2).Value.svalue)),resultdef,false)
                              else
                                result:=COrdConstNode.create(min(TOrdConstNode(hp).Value,TOrdConstNode(hp2).Value),resultdef,false);
                            end;

                          if is_minmax_deterministic(TOrdConstNode(hp), False, helperres) then
                            begin
                              if helperres then
                                result:=COrdConstNode.create(TOrdConstNode(hp).Value,resultdef,false)
                              else
                                result:=hp2.GetCopy();
                            end;
                        end
                      else if (hp2.nodetype=ordconstn) then
                        begin
                          if is_minmax_deterministic(TOrdConstNode(hp2), False, helperres) then
                            begin
                              if helperres then
                                result:=COrdConstNode.create(TOrdConstNode(hp2).Value,resultdef,false)
                              else
                                result:=hp.GetCopy();
                            end;
                        end;
                    end;
                end;
              in_max_longint,
              in_max_int64:
                begin
                  if left.nodetype=callparan then
                    begin
                      { Check to see if the result is deterministic }
                      hp:=TCallParaNode(left).paravalue;
                      hp2:=TCallParaNode(TCallParaNode(left).nextpara).paravalue;

                      if (hp.nodetype=ordconstn) then
                        begin
                          if (hp2.nodetype=ordconstn) then
                            begin
                              { Both actual parameters are constants, so take
                                the larger of the two right now }
                              if inlinenumber=in_max_longint then
                                result:=COrdConstNode.create(max(LongInt(TOrdConstNode(hp).Value.svalue),LongInt(TOrdConstNode(hp2).Value.svalue)),resultdef,false)
                              else
                                result:=COrdConstNode.create(max(TOrdConstNode(hp).Value,TOrdConstNode(hp2).Value),resultdef,false);
                            end;

                          if is_minmax_deterministic(TOrdConstNode(hp), True, helperres) then
                            begin
                              if helperres then
                                result:=COrdConstNode.create(TOrdConstNode(hp).Value,resultdef,false)
                              else
                                result:=hp2.GetCopy();
                            end;
                        end
                      else if (hp2.nodetype=ordconstn) then
                        begin
                          if is_minmax_deterministic(TOrdConstNode(hp2), True, helperres) then
                            begin
                              if helperres then
                                result:=COrdConstNode.create(TOrdConstNode(hp2).Value,resultdef,false)
                              else
                                result:=hp.GetCopy();
                            end;
                        end;
                    end;
                end;
              in_min_dword,
              in_min_qword:
                begin
                  if left.nodetype=callparan then
                    begin
                      { Check to see if the result is deterministic }
                      hp:=TCallParaNode(TCallParaNode(left).nextpara).paravalue;
                      hp2:=TCallParaNode(left).paravalue;

                      if (hp.nodetype=ordconstn) then
                        begin
                          if (hp2.nodetype=ordconstn) then
                            begin
                              { Both actual parameters are constants, so take
                                the smaller of the two right now }
                              if inlinenumber=in_min_dword then
                                result:=COrdConstNode.create(min(DWord(TOrdConstNode(hp).Value.uvalue),DWord(TOrdConstNode(hp2).Value.uvalue)),resultdef,false)
                              else
                                result:=COrdConstNode.create(min(TOrdConstNode(hp).Value,TOrdConstNode(hp2).Value),resultdef,false);
                            end;

                          if is_minmax_deterministic(TOrdConstNode(hp), False, helperres) then
                            begin
                              if helperres then
                                result:=COrdConstNode.create(TOrdConstNode(hp).Value,resultdef,false)
                              else
                                result:=hp2.GetCopy();
                            end;
                        end
                      else if (hp2.nodetype=ordconstn) then
                        begin
                          if is_minmax_deterministic(TOrdConstNode(hp2), False, helperres) then
                            begin
                              if helperres then
                                result:=COrdConstNode.create(TOrdConstNode(hp2).Value,resultdef,false)
                              else
                                result:=hp.GetCopy();
                            end;
                        end;
                    end;
                end;
              in_max_dword,
              in_max_qword:
                begin
                  if left.nodetype=callparan then
                    begin
                      { Check to see if the result is deterministic }
                      hp:=TCallParaNode(left).paravalue;
                      hp2:=TCallParaNode(TCallParaNode(left).nextpara).paravalue;

                      if (hp.nodetype=ordconstn) then
                        begin
                          if (hp2.nodetype=ordconstn) then
                            begin
                              { Both actual parameters are constants, so take
                                the larger of the two right now }
                              if inlinenumber=in_max_dword then
                                result:=COrdConstNode.create(max(DWord(TOrdConstNode(hp).Value.uvalue),DWord(TOrdConstNode(hp2).Value.uvalue)),resultdef,false)
                              else
                                result:=COrdConstNode.create(max(TOrdConstNode(hp).Value,TOrdConstNode(hp2).Value),resultdef,false);
                            end;

                          if is_minmax_deterministic(TOrdConstNode(hp), True, helperres) then
                            begin
                              if helperres then
                                result:=COrdConstNode.create(TOrdConstNode(hp).Value,resultdef,false)
                              else
                                result:=hp2.GetCopy();
                            end;
                        end
                      else if (hp2.nodetype=ordconstn) then
                        begin
                          if is_minmax_deterministic(TOrdConstNode(hp2), True, helperres) then
                            begin
                              if helperres then
                                result:=COrdConstNode.create(TOrdConstNode(hp2).Value,resultdef,false)
                              else
                                result:=hp.GetCopy();
                            end;
                        end;
                    end;
                end;
              else
                ;
            end;
          end;
      end;



    function TInlineNode.pass_typecheck:TNode;

      type
        TFloatTypeSet = set of TFloatType;

      function removefloatupcasts(var p: TNode; const floattypes: TFloatTypeSet): TDef;
        var
          hnode: TNode;
        begin
          { System unit declares internal functions like this:
              function foo(x: valreal): valreal; [internproc: number];
            Calls to such functions are initially processed by callnode,
            which typechecks the arguments, possibly inserting conversion to valreal.
            To handle smaller types without excess precision, we need to remove
            these extra typecasts. }
          if not(cs_excessprecision in CurrentSettings.LocalSwitches) and
             (p.nodetype=typeconvn) and
             (TTypeConvNode(p).left.resultdef.typ=floatdef) and
             (p.flags*[nf_explicit,nf_internal]=[]) and
             (TFloatDef(TTypeConvNode(p).left.resultdef).FloatType in (floattypes*[S32Real,S64Real,s80real,sc80real])) then
            begin
              hnode:=TTypeConvNode(p).left;
              TTypeConvNode(p).left:=nil;
              p.free;
              p:=hnode;
              result:=p.resultdef;
            end
          else if (p.nodetype=typeconvn) and
             (p.flags*[nf_explicit,nf_internal]=[]) and
             (TTypeConvNode(p).left.resultdef.typ=floatdef) and
             (TFloatDef(TTypeConvNode(p).left.resultdef).FloatType in (floattypes*[s64currency,s64comp])) then
            begin
              hnode:=TTypeConvNode(p).left;
              TTypeConvNode(p).left:=nil;
              p.free;
              p:=hnode;
              if Is_Currency(p.resultdef) then
                begin
                  if (nf_is_currency in p.flags) and
                     (p.nodetype=slashn) and
                     (TAddNode(p).right.nodetype=realconstn) and
                     (TRealConstNode(TAddNode(p).right).value_real=10000.0) and
                     not(nf_is_currency in TAddNode(p).left.flags) then
                   begin
                     hnode:=TAddNode(p).left;
                     TAddNode(p).left:=nil;
                     p.free;
                     p:=hnode;
                   end;
                end;
              result:=p.resultdef;
            end
          { in case the system helper was declared with overloads for different types,
            keep those }
          else if (p.resultdef.typ=floatdef) and
             (TFloatDef(p.resultdef).FloatType in (floattypes*[S32Real,S64Real,s80real,sc80real])) then
            result:=p.resultdef
          else
            begin
              { for variant parameters; the rest has been converted by the
                call node already }
              if not(p.nodetype in [ordconstn,realconstn]) then
                inserttypeconv(P,PBestRealType^);
              result:=p.resultdef
            end;
        end;


      procedure handle_pack_unpack;
        var
          source, target, index: TCallParaNode;
          unpackedarraydef, packedarraydef: TArrayDef;
          tempindex: TConstExprInt;
        begin
          resultdef:=VoidType;

          unpackedarraydef := nil;
          packedarraydef := nil;
          source := TCallParaNode(left);
          if (inlinenumber = in_unpack_x_y_z) then
            begin
              target := TCallParaNode(source.right);
              index := TCallParaNode(target.right);

              { source must be a packed array }
              if not Is_Packed_Array(source.left.resultdef) then
                CGMessagePos2(source.left.fileinfo,type_e_got_expected_packed_array,'1',source.left.resultdef.TypeName)
              else
                packedarraydef := TArrayDef(source.left.resultdef);
              { target can be any kind of array, as long as it's not packed }
              if (target.left.resultdef.typ <> arraydef) or
                 Is_Packed_Array(target.left.resultdef) then
                CGMessagePos2(target.left.fileinfo,type_e_got_expected_unpacked_array,'2',target.left.resultdef.TypeName)
              else
                unpackedarraydef := TArrayDef(target.left.resultdef);
            end
          else
            begin
              index := TCallParaNode(source.right);
              target := TCallParaNode(index.right);

              { source can be any kind of array, as long as it's not packed }
              if (source.left.resultdef.typ <> arraydef) or
                 Is_Packed_Array(source.left.resultdef) then
                CGMessagePos2(source.left.fileinfo,type_e_got_expected_unpacked_array,'1',source.left.resultdef.TypeName)
              else
                unpackedarraydef := TArrayDef(source.left.resultdef);
              { target must be a packed array }
              if not Is_Packed_Array(target.left.resultdef) then
                CGMessagePos2(target.left.fileinfo,type_e_got_expected_packed_array,'3',target.left.resultdef.TypeName)
              else
                packedarraydef := TArrayDef(target.left.resultdef);
            end;

          if Assigned(unpackedarraydef) then
            begin
              { index must be compatible with the unpacked array's indextype }
              inserttypeconv(index.left,unpackedarraydef.RangeDef);

              { range check at compile time if possible }
              if Assigned(packedarraydef) and
                 (index.left.nodetype = ordconstn) and
                 not Is_Special_Array(unpackedarraydef) then
                begin
                  AdaptRange(unpackedarraydef,TOrdConstNode(index.left).Value,false,false,cs_check_range in CurrentSettings.LocalSwitches);
                  tempindex := TOrdConstNode(index.left).Value + packedarraydef.HighRange-packedarraydef.LowRange;
                  AdaptRange(unpackedarraydef,tempindex,false,false,cs_check_range in CurrentSettings.LocalSwitches);
                end;
            end;

          { source array is read and must be valid }
          set_varstate(source.left,vs_read,[vsf_must_be_valid]);
          { target array is written }
          valid_for_assignment(target.left,true);
          set_varstate(target.left,vs_written,[]);
          { index in the unpacked array is read and must be valid }
          set_varstate(index.left,vs_read,[vsf_must_be_valid]);
          { if the size of the arrays is 0 (array of empty records), }
          { do nothing                                               }
          if (source.resultdef.Size = 0) then
            result:=CNothingNode.create;
        end;


      function handle_objc_encode: TNode;
        var
          encodedtype: AnsiString;
          errordef: TDef;
        begin
          encodedtype:='';
          if not objctryencodetype(left.resultdef,encodedtype,errordef) then
            Message1(type_e_objc_type_unsupported,errordef.TypeName);
          result:=CStringConstNode.createpchar(pchar(encodedtype),length(encodedtype),nil);
        end;

      var
         hightree,
         hp        : TNode;
         temp_pnode: PNode;
         convdef   : TDef;
      begin
        result:=nil;
        { when handling writeln "left" contains no valid address }
        if Assigned(left) then
          begin
            if left.nodetype=callparan then
              TCallParaNode(left).get_paratype
            else
              TypeCheckPass(left);
          end;

        if not(inf_inlineconst in inlinenodeflags) then
          begin
            case inlinenumber of
              in_lo_long,
              in_hi_long,
              in_lo_qword,
              in_hi_qword,
              in_lo_word,
              in_hi_word :
                begin
                  { give warning for incompatibility with Delphi }
                  if (inlinenumber in [in_lo_long,in_hi_long,in_lo_qword,in_hi_qword]) and
                     (m_delphi in CurrentSettings.ModeSwitches) then
                    CGMessage(type_w_maybe_wrong_hi_lo);
                  set_varstate(left,vs_read,[vsf_must_be_valid]);
                  if not Is_Integer(left.resultdef) then
                    CGMessage1(type_e_integer_expr_expected,left.resultdef.TypeName);
                  case inlinenumber of
                    in_lo_word,
                    in_hi_word :
                      resultdef:=U8IntType;
                    in_lo_long,
                    in_hi_long :
                      resultdef:=U16IntType;
                    in_lo_qword,
                    in_hi_qword :
                      resultdef:=U32IntType;
                    else
                      ;
                  end;
                end;

              in_sizeof_x:
                begin
                  { the constant evaluation of in_sizeof_x happens in pexpr where possible,
                    though for generics it can reach here as well }
                  set_varstate(left,vs_read,[]);
                  if (left.resultdef.typ<>undefineddef) and
                      Assigned(CurrentProcInfo) and
                      ParaManager.Push_High_Param(vs_value,left.resultdef,CurrentProcInfo.procdef.ProcCallOption) then
                   begin
                     { this should be an open array or array of const, both of
                       which can only be simple load nodes of parameters }
                     if left.nodetype<>loadn then
                       InternalError(2014120701);
                     hightree:=load_high_value_node(TParaVarSym(TLoadNode(left).symtableentry));
                     if Assigned(hightree) then
                      begin
                        hp:=CAddNode.create(addn,hightree,
                                         COrdConstNode.create(1,SizeSIntType,false));
                        if (left.resultdef.typ=arraydef) then
                          if not Is_Packed_Array(TArrayDef(left.resultdef)) then
                            begin
                              if (TArrayDef(left.resultdef).EleSize<>1) then
                                hp:=CAddNode.create(muln,hp,COrdConstNode.create(TArrayDef(
                                  left.resultdef).EleSize,SizeSIntType,true));
                            end
                          else if (TArrayDef(left.resultdef).ElePackedBitSize <> 8) then
                            begin
                              { no packed open array support yet }
                              if (hp.nodetype <> ordconstn) then
                                InternalError(2006081511);
                              hp.free;
                              hp := COrdConstNode.create(left.resultdef.Size,SizeSIntType,true);
{
                              hp:=
                                 ctypeconvnode.create_explicit(sizesinttype,
                                   cmoddivnode.create(divn,
                                     caddnode.create(addn,
                                       caddnode.create(muln,hp,cordconstnode.create(tarraydef(
                                         left.resultdef).elepackedbitsize,s64inttype,true)),
                                       cordconstnode.create(a,s64inttype,true)),
                                     cordconstnode.create(8,s64inttype,true)),
                                   sizesinttype);
}
                            end;
                        result:=hp;
                      end;
                   end
                  else
                   resultdef:=SizeSIntType;
                end;

              in_typeof_x:
                begin
                  TypeCheckPass(left);
                  set_varstate(left,vs_read,[]);
                  if (left.resultdef.typ=objectdef) and
                    not(oo_has_vmt in TObjectDef(left.resultdef).ObjectOptions) then
                      message(type_e_typeof_requires_vmt);
                  resultdef:=VoidPointerType;
                end;

              in_ord_x:
                begin
                   set_varstate(left,vs_read,[vsf_must_be_valid]);
                   case left.resultdef.typ of
                     orddef,
                     enumdef,
                     undefineddef :
                       ;
                     pointerdef :
                       begin
                         if not(m_mac in CurrentSettings.ModeSwitches) then
                           CGMessage1(type_e_ordinal_expr_expected,left.resultdef.TypeName);
                       end
                     else
                       CGMessage1(type_e_ordinal_expr_expected,left.resultdef.TypeName);
                   end;
                end;

             in_chr_byte:
               begin
                 set_varstate(left,vs_read,[vsf_must_be_valid]);
               end;

              in_length_x:
                begin
                  if ((left.resultdef.typ=arraydef) and
                      (not Is_Special_Array(left.resultdef) or
                       Is_Open_Array(left.resultdef))) or
                     (left.resultdef.typ=orddef) then
                    set_varstate(left,vs_read,[])
                  else
                    set_varstate(left,vs_read,[vsf_must_be_valid]);

                  case left.resultdef.typ of
                    variantdef:
                      begin
                        inserttypeconv(left,GetAnsiStringDef);
                      end;

                    stringdef :
                      begin
                        { we don't need string convertions here,  }
                        { except if from widestring to ansistring }
                        { and vice versa (that can change the     }
                        { length)                                 }
                        if (left.nodetype=typeconvn) and
                           (TTypeConvNode(left).left.resultdef.typ=stringdef) and
                           not(Is_Wide_Or_Unicode_String(left.resultdef) xor
                               Is_Wide_Or_Unicode_String(TTypeConvNode(left).left.resultdef)) then
                         begin
                           hp:=TTypeConvNode(left).left;
                           TTypeConvNode(left).left:=nil;
                           left.free;
                           left:=hp;
                         end;
                      end;
                    orddef :
                      begin
                        { will be handled in simplify }
                        if not Is_Char(left.resultdef) and
                           not Is_WideChar(left.resultdef) then
                          CGMessage(type_e_mismatch);
                      end;
                    pointerdef :
                      begin
                        if Is_PChar(left.resultdef) then
                         begin
                            hp := CCallParaNode.create(left,nil);
                            result := CCallNode.createintern('fpc_pchar_length',hp);
                            { make sure the left node doesn't get disposed, since it's }
                            { reused in the new node (JM)                              }
                            left:=nil;
                            exit;
                         end
                        else if Is_PWideChar(left.resultdef) then
                         begin
                            hp := CCallParaNode.create(left,nil);
                            result := CCallNode.createintern('fpc_pwidechar_length',hp);
                            { make sure the left node doesn't get disposed, since it's }
                            { reused in the new node (JM)                              }
                            left:=nil;
                            exit;
                         end
                        else
                         CGMessage(type_e_mismatch);
                      end;
                    arraydef :
                      begin
                        if Is_Open_Array(left.resultdef) or
                           Is_Array_Of_Const(left.resultdef) then
                         begin
                           hightree:=load_high_value_node(TParaVarSym(TLoadNode(left).symtableentry));
                           if Assigned(hightree) then
                             result:=CAddNode.create(addn,hightree,
                               COrdConstNode.create(1,SIntType,false));
                           exit;
                         end
                        { Length() for dynamic arrays is inlined }
                        else
                          begin
                            { will be handled in simplify }
                          end;
                      end;
                    undefineddef :
                      begin
                        if not (df_generic in CurrentProcInfo.procdef.DefOptions) then
                          CGMessage(type_e_mismatch);
                        { otherwise nothing }
                      end;
                    else
                      CGMessage(type_e_mismatch);
                  end;

                  { shortstring return an 8 bit value as the length
                    is the first byte of the string }
                  if Is_ShortString(left.resultdef) then
                    resultdef:=U8IntType
                  else
                    resultdef:=SizeSIntType;
                end;

              in_typeinfo_x:
                begin
                   if (left.resultdef.typ=enumdef) and
                      (TEnumDef(left.resultdef).HasJumps) and
                      (
                        (left.nodetype<>typen) or
                        not (sp_generic_para in TTypeNode(left).TypeSym.SymOptions)
                      ) then
                     CGMessage(type_e_no_type_info);
                   set_varstate(left,vs_read,[vsf_must_be_valid]);
                   resultdef:=VoidPointerType;
                end;

              in_gettypekind_x:
                begin
                  set_varstate(left,vs_read,[vsf_must_be_valid]);
                  resultdef:=TypeKindType;
                end;

              in_ismanagedtype_x:
                begin
                  set_varstate(left,vs_read,[vsf_must_be_valid]);
                  resultdef:=PasBool1Type;
                end;

              in_isconstvalue_x:
                begin
                  set_varstate(left,vs_read,[vsf_must_be_valid]);
                  resultdef:=PasBool1Type;
                end;

              in_assigned_x:
                begin
                  { the parser has already made sure the expression is valid }

                  { in case of a complex procvar, only check the "code" pointer }
                  if (TCallParaNode(left).left.resultdef.typ=procvardef) and
                     not TProcVarDef(TCallParaNode(left).left.resultdef).Is_AddressOnly then
                    begin
                      inserttypeconv_explicit(TCallParaNode(left).left,Search_System_Type('TMETHOD').typedef);
                      TCallParaNode(left).left:=CSubscriptNode.create(TSym(TAbstractRecordDef(TCallParaNode(left).left.resultdef).SymTable.find('CODE')),TCallParaNode(left).left);
                      TCallParaNode(left).get_paratype;
                    end;

                  { Postpone conversion into addnode until firstpass, so targets
                    may override first_assigned and insert specific code. }
                  set_varstate(TCallParaNode(left).left,vs_read,[vsf_must_be_valid]);
                  resultdef:=PasBool1Type;
                end;

              in_ofs_x :
                InternalError(2000101001);

              in_seg_x :
                begin
                  result := typecheck_seg;
                end;

              in_pred_x,
              in_succ_x:
                begin
                   set_varstate(left,vs_read,[vsf_must_be_valid]);
                   resultdef:=left.resultdef;
                   if Is_Ordinal(resultdef) or Is_TypeParam(resultdef) then
                     begin
                       if (resultdef.typ=enumdef) and
                          (TEnumDef(resultdef).HasJumps) and
                          not(m_delphi in CurrentSettings.ModeSwitches) and
                          not(nf_internal in flags) then
                         CGMessage(type_e_succ_and_pred_enums_with_assign_not_possible);
                     end
                   else
                     CGMessage(type_e_ordinal_expr_expected)
                end;

              in_copy_x:
                result:=handle_copy;

              in_initialize_x,
              in_finalize_x:
                begin
                  { inlined from pinline }
                  InternalError(200204231);
                end;
              in_setlength_x:
                begin
                  result:=handle_setlength;
                end;
              in_inc_x,
              in_dec_x:
                begin
                  resultdef:=VoidType;
                  if not(df_generic in CurrentProcInfo.procdef.DefOptions) then
                    begin
                      if Assigned(left) then
                        begin
                           { first param must be var }
                           valid_for_var(TCallParaNode(left).left,true);
                           set_varstate(TCallParaNode(left).left,vs_readwritten,[vsf_must_be_valid]);

                           if (left.resultdef.typ in [enumdef,pointerdef]) or
                              Is_Ordinal(left.resultdef) or
                              Is_Currency(left.resultdef) then
                            begin
                              { value of left gets changed -> must be unique }
                              set_unique(TCallParaNode(left).left);
                              { two paras ? }
                              if Assigned(TCallParaNode(left).right) then
                               begin
                                 if Is_Integer(TCallParaNode(left).right.resultdef) then
                                   begin
                                     set_varstate(TCallParaNode(TCallParaNode(left).right).left,vs_read,[vsf_must_be_valid]);
                                     { when range/overflow checking is on, we
                                       convert this to a regular add, and for proper
                                       checking we need the original type }
                                     if ([cs_check_range,cs_check_overflow]*CurrentSettings.LocalSwitches=[]) then
                                       if (TCallParaNode(left).left.resultdef.typ=pointerdef) then
                                         begin
                                           { don't convert values added to pointers into the pointer types themselves,
                                             because that will turn signed values into unsigned ones, which then
                                             goes wrong when they have to be multiplied with the size of the elements
                                             to which the pointer points in ncginl (mantis #17342) }
                                           if Is_Signed(TCallParaNode(TCallParaNode(left).right).left.resultdef) then
                                             inserttypeconv(TCallParaNode(TCallParaNode(left).right).left,TPointerDef(TCallParaNode(left).left.resultdef).Pointer_Arithmetic_Int_Type)
                                           else
                                             inserttypeconv(TCallParaNode(TCallParaNode(left).right).left,TPointerDef(TCallParaNode(left).left.resultdef).Pointer_Arithmetic_UInt_Type)
                                         end
                                       else if Is_Integer(TCallParaNode(left).left.resultdef) then
                                         inserttypeconv(TCallParaNode(TCallParaNode(left).right).left,TCallParaNode(left).left.resultdef)
                                       else
                                         inserttypeconv_internal(TCallParaNode(TCallParaNode(left).right).left,TCallParaNode(left).left.resultdef);
                                     if Assigned(TCallParaNode(TCallParaNode(left).right).right) then
                                       { should be handled in the parser (JM) }
                                       InternalError(2006020901);
                                   end
                                 else
                                   CGMessagePos(TCallParaNode(left).right.fileinfo,type_e_ordinal_expr_expected);
                               end;
                            end
                           { generic type parameter? }
                           else if Is_TypeParam(left.resultdef) then
                             begin
                               result:=CNothingNode.create;
                               exit;
                             end
                           else
                             begin
                               hp:=self;
                               if isunaryoverloaded(hp,[]) then
                                 begin
                                   { inc(rec) and dec(rec) assigns result value to argument }
                                   result:=CAssignmentNode.create(TCallParaNode(left).left.GetCopy,hp);
                                   exit;
                                 end
                               else
                                 CGMessagePos(left.fileinfo,type_e_ordinal_expr_expected);
                             end;
                        end
                      else
                        CGMessagePos(fileinfo,type_e_mismatch);
                    end;
                end;

              in_and_assign_x_y,
              in_or_assign_x_y,
              in_xor_assign_x_y,
              in_sar_assign_x_y,
              in_shl_assign_x_y,
              in_shr_assign_x_y,
              in_rol_assign_x_y,
              in_ror_assign_x_y:
                begin
                  resultdef:=VoidType;
                  if not(df_generic in CurrentProcInfo.procdef.DefOptions) then
                    begin
                      { first parameter must exist }
                      if not Assigned(left) or (left.nodetype<>callparan) then
                        InternalError(2017032501);
                      { second parameter must exist }
                      if not Assigned(TCallParaNode(left).right) or (TCallParaNode(left).right.nodetype<>callparan) then
                        InternalError(2017032502);
                      { third parameter must NOT exist }
                      if Assigned(TCallParaNode(TCallParaNode(left).right).right) then
                        InternalError(2017032503);

                      valid_for_var(TCallParaNode(TCallParaNode(left).right).left,true);
                      set_varstate(TCallParaNode(TCallParaNode(left).right).left,vs_readwritten,[vsf_must_be_valid]);

                      if Is_Integer(TCallParaNode(left).right.resultdef) then
                        begin
                          { value of right gets changed -> must be unique }
                          set_unique(TCallParaNode(TCallParaNode(left).right).left);
                          if Is_Integer(left.resultdef) then
                            begin
                              set_varstate(TCallParaNode(left).left,vs_read,[vsf_must_be_valid]);
                              { these nodes shouldn't be created, when range checking is on }
                              if [cs_check_range,cs_check_overflow]*LocalSwitches<>[] then
                                InternalError(2017032701);
                              if inlinenumber in [in_sar_assign_x_y,in_shl_assign_x_y,in_shr_assign_x_y,in_rol_assign_x_y,in_ror_assign_x_y] then
                                inserttypeconv(TCallParaNode(left).left,SIntType)
                              else
                                inserttypeconv(TCallParaNode(left).left,TCallParaNode(TCallParaNode(left).right).left.resultdef);
                            end
                          else
                            CGMessagePos(left.fileinfo,type_e_ordinal_expr_expected);
                        end
                      { generic type parameter? }
                      else if Is_TypeParam(TCallParaNode(left).right.resultdef) then
                        begin
                          result:=CNothingNode.create;
                          exit;
                        end
                      else
                        CGMessagePos(TCallParaNode(left).right.fileinfo,type_e_ordinal_expr_expected);
                    end;
                end;

              in_neg_assign_x,
              in_not_assign_x:
                begin
                  resultdef:=VoidType;
                  if not(df_generic in CurrentProcInfo.procdef.DefOptions) then
                    begin
                      valid_for_var(left,true);
                      set_varstate(left,vs_readwritten,[vsf_must_be_valid]);

                      if Is_Integer(left.resultdef) then
                        begin
                          { value of left gets changed -> must be unique }
                          set_unique(left);
                          { these nodes shouldn't be created, when range checking is on }
                          if [cs_check_range,cs_check_overflow]*CurrentSettings.LocalSwitches<>[] then
                            InternalError(2017040703);
                        end
                      { generic type parameter? }
                      else if Is_TypeParam(left.resultdef) then
                        begin
                          result:=CNothingNode.create;
                          exit;
                        end
                      else
                        CGMessagePos(left.fileinfo,type_e_ordinal_expr_expected);
                    end;
                end;

              in_read_x,
              in_readln_x,
              in_readstr_x,
              in_write_x,
              in_writeln_x,
              in_writestr_x :
                begin
                  result := handle_read_write;
                end;

              in_settextbuf_file_x :
                begin
                  resultdef:=VoidType;
                  { now we know the type of buffer }
                  hp:=CCallParaNode.create(COrdConstNode.create(
                     TCallParaNode(left).left.resultdef.Size,S32IntType,true),left);
                  result:=CCallNode.createintern('SETTEXTBUF',hp);
                  left:=nil;
                end;

              { the firstpass of the arg has been done in firstcalln ? }
              in_reset_typedfile,
              in_rewrite_typedfile,
              in_reset_typedfile_name,
              in_rewrite_typedfile_name :
                begin
                  result := handle_reset_rewrite_typed;
                end;

              in_str_x_string :
                begin
                  result:=handle_str;
                end;

              in_val_x :
                begin
                  result:=handle_val;
                end;

              in_include_x_y,
              in_exclude_x_y:
                begin
                  resultdef:=VoidType;
                  { the parser already checks whether we have two (and exactly two) }
                  { parameters (JM)                                                 }
                  { first param must be var }
                  valid_for_var(TCallParaNode(left).left,true);
                  set_varstate(TCallParaNode(left).left,vs_readwritten,[vsf_must_be_valid]);
                  { check type }
                  if (left.resultdef.typ=setdef) then
                    begin
                      { insert a type conversion       }
                      { to the type of the set elements  }
                      set_varstate(TCallParaNode(TCallParaNode(left).right).left,vs_read,[vsf_must_be_valid]);
                      inserttypeconv(TCallParaNode(TCallParaNode(left).right).left,
                        TSetDef(left.resultdef).ElementDef);
                    end
                  else if left.resultdef.typ<>undefineddef then
                    CGMessage(type_e_mismatch);
                end;
              in_pack_x_y_z,
              in_unpack_x_y_z :
                begin
                  handle_pack_unpack;
                end;

              in_slice_x:
                begin
                  result:=nil;
                  resultdef:=TCallParaNode(left).left.resultdef;
                  if (resultdef.typ <> arraydef) then
                    CGMessagePos(left.fileinfo,type_e_mismatch)
                  else if Is_Packed_Array(resultdef) then
                    CGMessagePos2(left.fileinfo,type_e_got_expected_unpacked_array,'1',resultdef.TypeName);
                  if not(Is_Integer(TCallParaNode(TCallParaNode(left).right).left.resultdef)) then
                    CGMessagePos1(TCallParaNode(left).right.fileinfo,
                      type_e_integer_expr_expected,
                      TCallParaNode(TCallParaNode(left).right).left.resultdef.TypeName);
                end;

              in_new_x:
                resultdef:=left.resultdef;

              in_low_x,
              in_high_x:
                begin
                  case left.resultdef.typ of
                    undefineddef,
                    orddef,
                    enumdef,
                    setdef:
                      ;
                    arraydef:
                      begin
                        if (inlinenumber=in_low_x) then
                          set_varstate(left,vs_read,[])
                        else
                         begin
                           if Is_Open_Array(left.resultdef) or
                              Is_Array_Of_Const(left.resultdef) then
                            begin
                              set_varstate(left,vs_read,[]);
                              result:=load_high_value_node(TParaVarSym(TLoadNode(left).symtableentry));
                            end
                           else
                             begin
                               set_varstate(left,vs_read,[]);
                               resultdef:=SizeSIntType;
                             end;
                         end;
                      end;
                    stringdef:
                      begin
                        if inlinenumber=in_low_x then
                         begin
                           set_varstate(left,vs_read,[]);
                         end
                        else
                         begin
                           if Is_Open_String(left.resultdef) then
                            begin
                              set_varstate(left,vs_read,[]);
                              result:=load_high_value_node(TParaVarSym(TLoadNode(left).symtableentry))
                            end
                           else if Is_DynamicString(left.resultdef) then
                              begin
                                result:=CInlineNode.create(in_length_x,false,left);
                                if cs_zerobasedstrings in CurrentSettings.LocalSwitches then
                                  result:=CAddNode.create(subn,result,COrdConstNode.create(1,SIntType,false));
                                { make sure the left node doesn't get disposed, since it's }
                                { reused in the new node (JM)                              }
                                left:=nil;
                              end
                         end;
                     end;
                    else
                      CGMessage(type_e_mismatch);
                  end;
                end;

              in_exp_real,
              in_frac_real,
              in_int_real,
              in_cos_real,
              in_sin_real,
              in_arctan_real,
              in_ln_real :
                begin
                  { on the Z80, the double result is returned in a var param, because
                    it's too big to fit in registers. In that case we have 2 parameters
                    and left.nodetype is a callparan. }
                  if left.nodetype = callparan then
                    temp_pnode := @TCallParaNode(left).left
                  else
                    temp_pnode := @left;
                  set_varstate(temp_pnode^,vs_read,[vsf_must_be_valid]);
                  { converting an int64 to double on platforms without }
                  { extended can cause precision loss                  }
                  if not(temp_pnode^.nodetype in [ordconstn,realconstn]) then
                    inserttypeconv(temp_pnode^,PBestRealType^);
                  resultdef:=PBestRealType^;
                end;

              in_trunc_real,
              in_round_real :
                begin
                  { on i8086, the int64 result is returned in a var param, because
                    it's too big to fit in a register or a pair of registers. In
                    that case we have 2 parameters and left.nodetype is a callparan. }
                  if left.nodetype=callparan then
                    temp_pnode:=@TCallParaNode(left).left
                  else
                    temp_pnode:=@left;
                  set_varstate(temp_pnode^,vs_read,[vsf_must_be_valid]);
                  { on platforms where comp and currency are "type int64", this is
                    handled via inlined system helpers (-> no need for special
                    handling of s64currency/s64comp for them) }
                  if inlinenumber=in_trunc_real then
                    removefloatupcasts(temp_pnode^,[S32Real,S64Real,s80real,sc80real,s64currency,s64comp])
                  else
                    removefloatupcasts(temp_pnode^,[S32Real,S64Real,s80real,sc80real,s64comp]);
                  if (inlinenumber=in_trunc_real) and
                     Is_Currency(temp_pnode^.resultdef) and
                     (nf_is_currency in temp_pnode^.flags) then
                    begin
                      result:=CModDivNode.create(divn,CTypeConvNode.Create_Internal(temp_pnode^.GetCopy,S64IntType),genintconstnode(10000));
                      exit;
                    end
                  else if Is_FPUComp(temp_pnode^.resultdef) then
                    begin
                      result:=CTypeConvNode.Create_Internal(temp_pnode^.GetCopy,S64IntType);
                      exit;
                    end;
                  resultdef:=S64IntType;
                end;

              in_pi_real :
                begin
                  resultdef:=PBestRealType^;
                end;

              in_abs_long:
                begin
                  set_varstate(left,vs_read,[vsf_must_be_valid]);
                  resultdef:=left.resultdef;
                end;

              in_abs_real,
              in_sqr_real,
              in_sqrt_real :
                begin
                  { on the Z80, the double result is returned in a var param, because
                    it's too big to fit in registers. In that case we have 2 parameters
                    and left.nodetype is a callparan. }
                  if left.nodetype = callparan then
                    temp_pnode := @TCallParaNode(left).left
                  else
                    temp_pnode := @left;
                  set_varstate(temp_pnode^,vs_read,[vsf_must_be_valid]);
                  resultdef:=removefloatupcasts(temp_pnode^,[S32Real,S64Real,s80real,sc80real]);
                end;

              in_aligned_x,
              in_unaligned_x:
                begin
                  resultdef:=left.resultdef;
                end;
              in_volatile_x:
                begin
                  resultdef:=left.resultdef;
                  { volatile only makes sense if the value is in memory }
                  make_not_regable(left,[ra_addr_regable]);
                end;
              in_assert_x_y :
                begin
                  resultdef:=VoidType;
                  if Assigned(left) then
                    begin
                      set_varstate(TCallParaNode(left).left,vs_read,[vsf_must_be_valid]);
                      { check type }
                      if Is_Boolean(left.resultdef) or
                          (
                            (left.resultdef.typ=undefineddef) and
                            (df_generic in CurrentProcInfo.procdef.DefOptions)
                          ) then
                        begin
                           set_varstate(TCallParaNode(TCallParaNode(left).right).left,vs_read,[vsf_must_be_valid]);
                           { must always be a string }
                           inserttypeconv(TCallParaNode(TCallParaNode(left).right).left,CShortStringType);
                         end
                       else
                         CGMessage1(type_e_boolean_expr_expected,left.resultdef.TypeName);
                    end
                  else
                    CGMessage(type_e_mismatch);

                  if (cs_do_assertion in CurrentSettings.LocalSwitches) then
                    include(CurrentProcInfo.flags,pi_do_call);
                end;
              in_prefetch_var:
                resultdef:=VoidType;
              in_get_frame,
              in_get_caller_frame,
              in_get_caller_addr:
                begin
                  resultdef:=VoidPointerType;
                end;
              in_rol_x,
              in_ror_x,
              in_sar_x:
                begin
                  set_varstate(left,vs_read,[vsf_must_be_valid]);
                  resultdef:=left.resultdef;
                end;
              in_rol_x_y,
              in_ror_x_y,
              in_sar_x_y:
                begin
                  set_varstate(TCallParaNode(left).left,vs_read,[vsf_must_be_valid]);
                  set_varstate(TCallParaNode(TCallParaNode(left).right).left,vs_read,[vsf_must_be_valid]);
                  resultdef:=TCallParaNode(TCallParaNode(left).right).left.resultdef;
                end;
              in_bsf_x,
              in_bsr_x:
                 begin
                   set_varstate(left,vs_read,[vsf_must_be_valid]);
                   if not Is_Integer(left.resultdef) then
                     CGMessage1(type_e_integer_expr_expected,left.resultdef.TypeName);
                   if TOrdDef(left.resultdef).OrdType in [u64bit, s64bit] then
                     resultdef:=U64IntType
                   else
                     resultdef:=U32IntType
                 end;

              in_popcnt_x:
                 begin
                   set_varstate(left,vs_read,[vsf_must_be_valid]);
                   if not Is_Integer(left.resultdef) then
                     CGMessage1(type_e_integer_expr_expected,left.resultdef.TypeName);
                   resultdef:=left.resultdef;
                 end;

              in_objc_selector_x:
                begin
                  result:=CObjCSelectorNode.create(left);
                  { reused }
                  left:=nil;
                end;
              in_objc_protocol_x:
                begin
                  result:=CObjCProtocolNode.create(left);
                  { reused }
                  left:=nil;
                end;
              in_objc_encode_x:
                begin
                  result:=handle_objc_encode;
                end;
              in_default_x:
                begin
                  result:=handle_default;
                end;
              in_box_x:
                begin
                  result:=handle_box;
                end;
              in_unbox_x_y:
                begin
                  result:=handle_unbox;
                end;
              in_fma_single,
              in_fma_double,
              in_fma_extended:
                begin
                  set_varstate(TCallParaNode(left).left,vs_read,[vsf_must_be_valid]);
                  set_varstate(TCallParaNode(TCallParaNode(left).right).left,vs_read,[vsf_must_be_valid]);
                  set_varstate(TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).left,vs_read,[vsf_must_be_valid]);
                  resultdef:=TCallParaNode(left).left.resultdef;
                end;
              in_max_longint,
              in_max_dword,
              in_min_longint,
              in_min_dword,
              in_max_int64,
              in_max_qword,
              in_min_int64,
              in_min_qword,
              in_max_single,
              in_max_double,
              in_min_single,
              in_min_double:
                begin
                  set_varstate(TCallParaNode(left).left,vs_read,[vsf_must_be_valid]);
                  set_varstate(TCallParaNode(TCallParaNode(left).right).left,vs_read,[vsf_must_be_valid]);
                  resultdef:=TCallParaNode(left).left.resultdef;
                end;
              in_delete_x_y_z:
                begin
                  result:=handle_delete;
                end;
              in_insert_x_y_z:
                begin
                  result:=handle_insert;
                end;
              in_concat_x:
                begin
                  result:=handle_concat;
                end;
              in_atomic_dec,
              in_atomic_inc,
              in_atomic_xchg,
              in_atomic_cmp_xchg:
                begin
                  { first parameter must exist for all }
                  if not Assigned(left) or (left.nodetype<>callparan) then
                    InternalError(2022093001);
                  { second parameter must exist for xchg and cmp_xchg }
                  if (inlinenumber=in_atomic_xchg) or (inlinenumber=in_atomic_cmp_xchg) then
                    begin
                      if not Assigned(TCallParaNode(left).right) or (TCallParaNode(left).right.nodetype<>callparan) then
                        InternalError(2022093002);
                      if inlinenumber=in_atomic_cmp_xchg then
                        begin
                          { third parameter must exist }
                          if not Assigned(TCallParaNode(TCallParaNode(left).right).right) or (TCallParaNode(TCallParaNode(left).right).right.nodetype<>callparan) then
                            InternalError(2022093004);
                          { fourth parameter may exist }
                          if Assigned(TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).right) then
                            begin
                              if TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).right.nodetype<>callparan then
                                InternalError(2022093005);
                              { fifth parameter must NOT exist }
                              if Assigned(TCallParaNode(TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).right).right) then
                                InternalError(2022093006);
                            end;
                        end
                      { third parameter must NOT exist }
                      else if Assigned(TCallParaNode(TCallParaNode(left).right).right) then
                        InternalError(2022093003);
                    end
                  else if Assigned(TCallParaNode(left).right) then
                    begin
                      { if the second parameter exists, it must be a callparan }
                      if TCallParaNode(left).right.nodetype<>callparan then
                        InternalError(2022093004);
                      { a third parameter must not exist }
                      if Assigned(TCallParaNode(TCallParaNode(left).right).right) then
                        InternalError(2022093005);
                    end;

                  valid_for_var(TCallParaNode(left).left,true);
                  set_varstate(TCallParaNode(left).left,vs_readwritten,[vsf_must_be_valid]);

                  if Is_Integer(TCallParaNode(left).resultdef) or Is_Pointer(TCallParaNode(left).resultdef) then
                    begin
                      if not Is_Pointer(TCallParaNode(left).resultdef) then
                        begin
                          resultdef:=Get_Signed_IntType(TCallParaNode(left).left.resultdef);
                          convdef:=resultdef;
                        end
                      else
                        begin
                          { pointer is only allowed for Exchange and CmpExchange }
                          if (inlinenumber<>in_atomic_xchg) and (inlinenumber<>in_atomic_cmp_xchg) then
                            CGMessagePos(fileinfo,type_e_ordinal_expr_expected);
                          resultdef:=VoidPointerType;
                          convdef:=PtrSIntType;
                        end;
                      { left gets changed -> must be unique }
                      set_unique(TCallParaNode(left).left);
                      inserttypeconv_internal(TCallParaNode(left).left,convdef);
                      if Assigned(TCallParaNode(left).right) then
                        begin
                          inserttypeconv(TCallParaNode(TCallParaNode(left).right).left,resultdef);
                          if resultdef<>convdef then
                            inserttypeconv_internal(TCallParaNode(TCallParaNode(left).right).left,convdef);
                          if Assigned(TCallParaNode(TCallParaNode(left).right).right) then
                            begin
                              inserttypeconv(TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).left,resultdef);
                              if resultdef<>convdef then
                                inserttypeconv_internal(TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).left,convdef);
                              if Assigned(TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).right) then
                                begin
                                  { the boolean parameter must be assignable }
                                  valid_for_var(TCallParaNode(TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).right).left,true);
                                  set_varstate(TCallParaNode(TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).right).left,vs_written,[]);
                                  if not Is_Boolean(TCallParaNode(TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).right).left.resultdef) then
                                    inserttypeconv(TCallParaNode(TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).right).left,PasBool1Type);
                                end;
                            end;
                        end;
                    end
                  else if Is_TypeParam(TCallParaNode(left).left.resultdef) then
                    begin
                      resultdef:=TCallParaNode(left).left.resultdef;
                    end
                  else if (inlinenumber=in_atomic_xchg) or (inlinenumber=in_atomic_cmp_xchg) then
                    CGMessagePos(TCallParaNode(left).left.fileinfo,type_e_ordinal_or_pointer_expr_expected)
                  else
                    CGMessagePos(TCallParaNode(left).left.fileinfo,type_e_ordinal_expr_expected);
                end;
              else
                result:=pass_typecheck_cpu;
            end;
          end;

        if not Assigned(result) and not
           CodeGenError then
          result:=simplify(false);
      end;


    function TInlineNode.pass_typecheck_cpu : TNode;
      begin
        Result:=nil;

        Message1(cg_f_unknown_internal_procedure_number,ToStr(ord(inlinenumber)));
      end;


    function TInlineNode.pass_1 : TNode;
      var
         hp: TNode;
         shiftconst: LongInt;
         objdef: TObjectDef;
         sym : TSym;
         hdef: TDef;

      begin
         result:=nil;
         { if we handle writeln; left contains no valid address }
         if Assigned(left) then
           begin
              if left.nodetype=callparan then
                TCallParaNode(left).firstcallparan
              else
                FirstPass(left);
           end;

         { intern const should already be handled }
         if inf_inlineconst in inlinenodeflags then
          InternalError(200104044);
         case inlinenumber of
          in_lo_qword,
          in_hi_qword,
          in_lo_long,
          in_hi_long,
          in_lo_word,
          in_hi_word:
            begin
              shiftconst := 0;
              case inlinenumber of
                in_hi_qword:
                  shiftconst := 32;
                in_hi_long:
                  shiftconst := 16;
                in_hi_word:
                  shiftconst := 8;
                else
                  ;
              end;
              if shiftconst <> 0 then
                result := CTypeConvNode.Create_Internal(CShlShrNode.create(shrn,left,
                    COrdConstNode.create(shiftconst,SIntType,false)),resultdef)
              else
                result := CTypeConvNode.Create_Internal(left,resultdef);
              left := nil;
              FirstPass(result);
            end;

          in_sizeof_x,
          in_typeof_x:
            begin
              expectloc:=LOC_REGISTER;
              case left.resultdef.typ of
                objectdef,classrefdef:
                  begin
                    if left.resultdef.typ=objectdef then
                      begin
                        result:=CLoadVMTAddrNode.create(left);
                        objdef:=TObjectDef(left.resultdef);
                      end
                    else
                      begin
                        result:=left;
                        objdef:=TObjectDef(TClassRefDef(left.resultdef).PointedDef);
                      end;
                    left:=nil;
                    if inlinenumber=in_sizeof_x then
                      begin
                        inserttypeconv_explicit(result,CPointerDef.getreusable(objdef.VMT_Def));
                        result:=CDerefNode.create(result);
                        result:=genloadfield(result,'VINSTANCESIZE');
                      end
                    else
                      inserttypeconv_explicit(result,VoidPointerType);
                  end;
                undefineddef:
                  ;
                else
                  InternalError(2015122702);
              end;
            end;

          in_length_x:
            begin
               result:=first_length;
            end;

          in_typeinfo_x:
            begin
              if (left.resultdef.typ=enumdef) and
                 (TEnumDef(left.resultdef).HasJumps) then
                begin
                  if (left.nodetype=typen) and (sp_generic_para in TTypeNode(left).TypeSym.SymOptions) then
                    result:=CNilNode.create
                  else
                    InternalError(2021032601);
                end
              else
                result:=CAddrNode.Create_Internal(
                  CRTTINode.create(TStoredDef(left.resultdef),fullrtti,rdt_normal)
                );
            end;

          in_gettypekind_x:
            begin
              sym:=TEnumDef(TypeKindType).Int2EnumSym(Get_TypeKind(left.resultdef));
              if not Assigned(sym) then
                InternalError(2017081101);
              if sym.typ<>enumsym then
                InternalError(2017081102);
              result:=genenumnode(TEnumSym(sym));
            end;

          in_ismanagedtype_x:
            begin
              if left.resultdef.NeedsInitTable then
                result:=COrdConstNode.create(1,resultdef,false)
              else
                result:=COrdConstNode.create(0,resultdef,false);
            end;

          in_isconstvalue_x:
            begin
              if is_constnode(left) then
                result:=COrdConstNode.create(1,resultdef,false)
              else
                result:=COrdConstNode.create(0,resultdef,false);
            end;

          in_assigned_x:
            begin
              result:=first_assigned;
            end;

          in_pred_x,
          in_succ_x:
            begin
              expectloc:=LOC_REGISTER;
              { in case of range/overflow checking, use a regular addnode
                because it's too complex to handle correctly otherwise }

              if (([cs_check_overflow,cs_check_range]*CurrentSettings.LocalSwitches)<>[]) and not(nf_internal in flags) then
                begin
                  { create constant 1, ensure the data type is large enough }
                  Range_To_Type(
                    min(1,Get_Min_Value(left.resultdef)),
                    max(1,Get_Max_Value(left.resultdef)),hdef);
                  hp:=COrdConstNode.create(1,hdef,false);
                  TypeCheckPass(hp);
                  if not Is_Integer(hp.resultdef) then
                    inserttypeconv_internal(hp,SIntType);

                  { avoid type errors from the addn/subn }
                  if not Is_Integer(left.resultdef) then
                    inserttypeconv_internal(left,SIntType);

                  { addition/subtraction depending on succ/pred }
                  if inlinenumber=in_succ_x then
                    hp:=CAddNode.create(addn,left,hp)
                  else
                    hp:=CAddNode.create(subn,left,hp);


                  if nf_internal in flags then
                    include(hp.flags,nf_internal);

                  { assign result of addition }
                  if not(Is_Integer(resultdef)) then
                    inserttypeconv(hp,COrdDef.create(
{$ifdef cpu64bitaddr}
                      s64bit,
{$else cpu64bitaddr}
                      s32bit,
{$endif cpu64bitaddr}
                      Get_Min_Value(resultdef),
                      Get_Max_Value(resultdef),
                      true))
                  else
                    inserttypeconv(hp,resultdef);

                  if nf_internal in flags then
                    include(hp.flags,nf_internal);

                  { avoid any possible errors/warnings }
                  inserttypeconv_internal(hp,resultdef);

                  { firstpass it }
                  FirstPass(hp);

                  { left is reused }
                  left:=nil;

                  { return new node }
                  result:=hp;
                end;
            end;

          in_setlength_x:
            result:=first_setlength;
          in_copy_x:
            result:=first_copy;
          in_initialize_x,
          in_finalize_x:
            begin
              expectloc:=LOC_VOID;
            end;

          in_inc_x,
          in_dec_x:
            begin
              result:=first_IncDec;
            end;

          in_and_assign_x_y,
          in_or_assign_x_y,
          in_xor_assign_x_y,
          in_sar_assign_x_y,
          in_shl_assign_x_y,
          in_shr_assign_x_y,
          in_rol_assign_x_y,
          in_ror_assign_x_y:
            begin
              result:=first_AndOrXorShiftRot_assign;
            end;

          in_neg_assign_x,
          in_not_assign_x:
            begin
              result:=first_NegNot_assign;
            end;

         in_include_x_y,
         in_exclude_x_y:
           begin
              result:=first_IncludeExclude;
           end;

         in_pack_x_y_z,
         in_unpack_x_y_z:
           begin
             result:=first_pack_unpack;
           end;

         in_exp_real:
           begin
             result:= first_exp_real;
           end;

         in_round_real:
           begin
             result:= first_round_real;
           end;

         in_trunc_real:
           begin
             result:= first_trunc_real;
           end;

         in_int_real:
           begin
             result:= first_int_real;
           end;

         in_frac_real:
           begin
             result:= first_frac_real;
           end;

         in_cos_real:
           begin
             result:= first_cos_real;
           end;

         in_sin_real:
           begin
             result := first_sin_real;
           end;

         in_arctan_real:
           begin
             result := first_arctan_real;
           end;

         in_pi_real :
           begin
             result := first_pi;
           end;

         in_abs_real:
           begin
             result := first_abs_real;
           end;

         in_abs_long:
           begin
             result := first_abs_long;
           end;

         in_sqr_real:
           begin
             result := first_sqr_real;
           end;

         in_sqrt_real:
           begin
             result := first_sqrt_real;
           end;

         in_ln_real:
           begin
             result := first_ln_real;
           end;


         in_assert_x_y :
            begin
              result:=first_assert;
            end;

          in_low_x:
            InternalError(200104047);
          in_high_x:
            begin
              result:=first_high;
            end;

          in_slice_x:
            { slice can be used only in calls for open array parameters, so it has to be converted appropriately before
              if we get here, the array could not be passed to an open array parameter so it is an error }
            CGMessagePos(left.fileinfo,type_e_mismatch);

          in_ord_x,
          in_chr_byte:
            begin
               { should not happened as it's converted to typeconv }
               InternalError(200104045);
            end;

          in_ofs_x :
            InternalError(2000101002);

          in_seg_x :
            begin
              result:=first_seg;
            end;

          in_settextbuf_file_x,
          in_reset_typedfile,
          in_rewrite_typedfile,
          in_reset_typedfile_name,
          in_rewrite_typedfile_name,
          in_str_x_string,
          in_val_x,
          in_read_x,
          in_readln_x,
          in_write_x,
          in_writeln_x :
            begin
              { should be handled by pass_typecheck }
              InternalError(2001082302);
            end;
         in_get_frame:
            begin
              result:=first_get_frame;
            end;
         in_get_caller_frame:
            begin
              expectloc:=LOC_REGISTER;
            end;
         in_get_caller_addr:
            begin
              expectloc:=LOC_REGISTER;
            end;
         in_prefetch_var:
           begin
             expectloc:=LOC_VOID;
           end;
         in_aligned_x,
         in_unaligned_x,
         in_volatile_x:
           begin
             expectloc:=TCallParaNode(left).left.expectloc;
           end;
         in_rol_x,
         in_rol_x_y,
         in_ror_x,
         in_ror_x_y:
           expectloc:=LOC_REGISTER;
         in_bsf_x,
         in_bsr_x:
           result:=first_bitscan;
         in_sar_x,
         in_sar_x_y:
           result:=first_sar;
         in_popcnt_x:
           result:=first_popcnt;
         in_new_x:
           result:=first_new;
         in_box_x:
           result:=first_box;
         in_unbox_x_y:
           result:=first_unbox;
         in_fma_single,
         in_fma_double,
         in_fma_extended:
           result:=first_fma;
         in_max_longint,
         in_max_dword,
         in_min_longint,
         in_min_dword,
         in_max_int64,
         in_max_qword,
         in_min_int64,
         in_min_qword,
         in_min_single,
         in_min_double,
         in_max_single,
         in_max_double:
           result:=first_minmax;
         in_atomic_inc,
         in_atomic_dec,
         in_atomic_xchg,
         in_atomic_cmp_xchg:
           result:=first_atomic;
         else
           result:=first_cpu;
          end;
       end;
{$maxfpuregisters default}

    function TInlineNode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (inlinenumber = TInlineNode(p).inlinenumber);
      end;


    procedure TInlineNode.mark_write;
      begin
        case inlinenumber of
	  in_aligned_x, in_unaligned_x:
           TCallParaNode(left).left.mark_write;
        else
          inherited mark_write;
        end;
      end;

    function TInlineNode.first_pi : TNode;
      begin
        result:=CRealConstNode.create(Pi,PBestRealType^);
      end;


     function TInlineNode.first_arctan_real : TNode;
      var
        temp_pnode: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if left.nodetype = callparan then
          temp_pnode := @TCallParaNode(left).left
        else
          temp_pnode := @left;
        result := CCallNode.createintern('fpc_arctan_real',
                CCallParaNode.create(temp_pnode^,nil));
        temp_pnode^ := nil;
      end;

     function TInlineNode.first_abs_real : TNode;
      var
         callnode : TCallNode;
         temp_pnode: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if left.nodetype = callparan then
          temp_pnode := @TCallParaNode(left).left
        else
          temp_pnode := @left;
        callnode:=CCallNode.createintern('fpc_abs_real',
                    CCallParaNode.create(temp_pnode^,nil));
        result := CTypeConvNode.create(callnode,resultdef);
        include(callnode.callnodeflags,cnf_check_fpu_exceptions);
        temp_pnode^ := nil;
      end;

     function TInlineNode.first_sqr_real : TNode;
      begin
        { All retained CPUs implement this in their CPU-specific inline node. }
        InternalError(2011092401);
        result:=nil;
      end;

     function TInlineNode.first_sqrt_real : TNode;
      var
        callnode: TCallNode;
        temp_pnode: PNode;
      begin
        if left.nodetype = callparan then
          temp_pnode := @TCallParaNode(left).left
        else
          temp_pnode := @left;
        { create the call to the helper }
        { on entry left node contains the parameter }
        callnode := CCallNode.createintern('fpc_sqrt_real',
            CCallParaNode.create(temp_pnode^,nil));
        result := CTypeConvNode.create(callnode,resultdef);
        include(callnode.callnodeflags,cnf_check_fpu_exceptions);
        temp_pnode^ := nil;
      end;

     function TInlineNode.first_ln_real : TNode;
      var
        temp_pnode: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if left.nodetype = callparan then
          temp_pnode := @TCallParaNode(left).left
        else
          temp_pnode := @left;
        result := CCallNode.createintern('fpc_ln_real',
                CCallParaNode.create(temp_pnode^,nil));
        include(TCallNode(result).callnodeflags,cnf_check_fpu_exceptions);
        temp_pnode^ := nil;
      end;

     function TInlineNode.first_cos_real : TNode;
      var
        temp_pnode: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if left.nodetype = callparan then
          temp_pnode := @TCallParaNode(left).left
        else
          temp_pnode := @left;
        result := CCallNode.createintern('fpc_cos_real',
                CCallParaNode.create(temp_pnode^,nil));
        include(TCallNode(result).callnodeflags,cnf_check_fpu_exceptions);
        temp_pnode^ := nil;
      end;

     function TInlineNode.first_sin_real : TNode;
      var
        temp_pnode: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if left.nodetype = callparan then
          temp_pnode := @TCallParaNode(left).left
        else
          temp_pnode := @left;
        result := CCallNode.createintern('fpc_sin_real',
                CCallParaNode.create(temp_pnode^,nil));
        include(TCallNode(result).callnodeflags,cnf_check_fpu_exceptions);
        temp_pnode^ := nil;
      end;

     function TInlineNode.first_exp_real : TNode;
      var
        temp_pnode: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if left.nodetype = callparan then
          temp_pnode := @TCallParaNode(left).left
        else
          temp_pnode := @left;
        result := CCallNode.createintern('fpc_exp_real',CCallParaNode.create(temp_pnode^,nil));
        include(TCallNode(result).callnodeflags,cnf_check_fpu_exceptions);
        temp_pnode^ := nil;
      end;

     function TInlineNode.first_int_real : TNode;
      var
        temp_pnode: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if left.nodetype = callparan then
          temp_pnode := @TCallParaNode(left).left
        else
          temp_pnode := @left;
        result := CCallNode.createintern('fpc_int_real',CCallParaNode.create(temp_pnode^,nil));
        include(TCallNode(result).callnodeflags,cnf_check_fpu_exceptions);
        temp_pnode^ := nil;
      end;

     function TInlineNode.first_frac_real : TNode;
      var
        temp_pnode: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if left.nodetype = callparan then
          temp_pnode := @TCallParaNode(left).left
        else
          temp_pnode := @left;
        result := CCallNode.createintern('fpc_frac_real',CCallParaNode.create(temp_pnode^,nil));
        include(TCallNode(result).callnodeflags,cnf_check_fpu_exceptions);
        temp_pnode^ := nil;
      end;

     function TInlineNode.first_round_real : TNode;
      var
        temp_pnode: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if left.nodetype = callparan then
          temp_pnode := @TCallParaNode(left).left
        else
          temp_pnode := @left;
        result := CCallNode.createintern('fpc_round_real',CCallParaNode.create(temp_pnode^,nil));
        include(TCallNode(result).callnodeflags,cnf_check_fpu_exceptions);
        temp_pnode^ := nil;
      end;

     function TInlineNode.first_trunc_real : TNode;
      var
        temp_pnode: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if left.nodetype = callparan then
          temp_pnode := @TCallParaNode(left).left
        else
          temp_pnode := @left;
        result := CCallNode.createintern('fpc_trunc_real',CCallParaNode.create(temp_pnode^,nil));
        include(TCallNode(result).callnodeflags,cnf_check_fpu_exceptions);
        temp_pnode^ := nil;
      end;


     function TInlineNode.first_abs_long : TNode;
      begin
        expectloc:=LOC_REGISTER;
        result:=nil;
      end;


     function TInlineNode.getaddsub_for_incdec : TNode;
       var
         hp,hpp,resultnode  : TNode;
         tempnode: TTempCreateNode;
         newstatement: TStatementNode;
         newblock: TBlockNode;
         hdef: TDef;
       begin
         newblock := internalstatements(newstatement);
         { extra parameter? }
         if Assigned(TCallParaNode(left).right) then
           begin
             { Yes, use for add node }
             hpp := TCallParaNode(TCallParaNode(left).right).left;
             TCallParaNode(TCallParaNode(left).right).left := nil;
             if Assigned(TCallParaNode(TCallParaNode(left).right).right) then
               { A syntax error should have already been raised }
               InternalError(2025050601);
           end
         else
           begin
             { no, create constant 1, ensure the data type is large enough }
             Range_To_Type(
               min(1,Get_Min_Value(TCallParaNode(left).left.resultdef)),
               max(1,Get_Max_Value(TCallParaNode(left).left.resultdef)),hdef);
             hpp:=COrdConstNode.create(1,hdef,false)
           end;
         TypeCheckPass(hpp);

         { make sure we don't call functions part of the left node twice (and generally }
         { optimize the code generation)                                                }
         { Storing address is not always an optimization: alignment of left is not known
           at this point, so we must assume the worst and use an unaligned pointer.
           This results in larger and slower code on alignment-sensitive targets.
           Therefore the complexity condition below is questionable, maybe just filtering
           out calls with "= NODE_COMPLEXITY_INF" is sufficient.
           Value of 3 corresponds to subscript nodes, i.e. record field. }
         if node_complexity(TCallParaNode(left).left) > 3 then
           begin
             tempnode := CTempCreateNode.create(VoidPointerType,VoidPointerType.Size,tt_persistent,true);
             addstatement(newstatement,tempnode);
             addstatement(newstatement,CAssignmentNode.create(CTempRefNode.create(tempnode),
               CAddrNode.Create_Internal(TCallParaNode(left).left.GetCopy)));
             hp := CDerefNode.create(CTempRefNode.create(tempnode));
             inserttypeconv_internal(hp,TCallParaNode(left).left.resultdef);
           end
         else
           begin
             hp := TCallParaNode(left).left.GetCopy;
             tempnode := nil;
           end;

         resultnode := hp.GetCopy;
         { Remove "modify" flag from what will be an assignment destination }
         Exclude(resultnode.flags, nf_modify);

         { avoid type errors from the addn/subn }
         if not Is_Integer(resultnode.resultdef) then
           begin
             inserttypeconv_internal(hp,SIntType);
             inserttypeconv_internal(hpp,SIntType);
           end;

         { addition/subtraction depending on inc/dec }
         if inlinenumber = in_inc_x then
           hpp := CAddNode.Create_Internal(addn,hp,hpp)
         else
           hpp := CAddNode.Create_Internal(subn,hp,hpp);

         { assign result of addition }

         { inherit internal flag }
         if not(Is_Integer(resultnode.resultdef)) then
           begin
             if nf_internal in flags then
               inserttypeconv_internal(hpp,COrdDef.create(
{$ifdef cpu64bitaddr}
                 s64bit,
{$else cpu64bitaddr}
                 s32bit,
{$endif cpu64bitaddr}
                 Get_Min_Value(resultnode.resultdef),
                 Get_Max_Value(resultnode.resultdef),
                 true))
             else
               inserttypeconv(hpp,COrdDef.create(
{$ifdef cpu64bitaddr}
                 s64bit,
{$else cpu64bitaddr}
                 s32bit,
{$endif cpu64bitaddr}
                 Get_Min_Value(resultnode.resultdef),
                 Get_Max_Value(resultnode.resultdef),
                 true))
           end
         else
           begin
             if nf_internal in flags then
               inserttypeconv_internal(hpp,resultnode.resultdef)
             else
               inserttypeconv(hpp,resultnode.resultdef);
           end;

         { avoid any possible warnings }
         inserttypeconv_internal(hpp,resultnode.resultdef);

         { force pass 1, so copied trees get first pass'ed as well and flags like
           nf_call_unique get set right }
         node_reset_pass1_write(hpp);
         DoTypeCheckPass(hpp);

         addstatement(newstatement,CAssignmentNode.create(resultnode,hpp));

         { firstpass it }
         FirstPass(TNode(newstatement.left));

         { deallocate the temp }
         if Assigned(tempnode) then
           addstatement(newstatement,CTempDeleteNode.create(tempnode));
         { firstpass it }
         FirstPass(TNode(newblock));
         { return new node }
         result := newblock;
       end;


     function TInlineNode.first_IncDec: TNode;
       begin
         expectloc:=LOC_VOID;
         result:=nil;

         { range/overflow checking doesn't work properly }
         { with the inc/dec code that's generated (JM)   }
         if ((LocalSwitches * [cs_check_overflow,cs_check_range] <> []) and
           { No overflow check for pointer operations, because inc(pointer,-1) will always
             trigger an overflow. For uint32 it works because then the operation is done
             in 64bit. Range checking is not applicable to pointers either }
             (TCallParaNode(left).left.resultdef.typ<>pointerdef))
            then
             { convert to simple add (JM) }
             result:=getaddsub_for_incdec
       end;


     function TInlineNode.first_IncludeExclude: TNode;
       begin
         result:=nil;
         expectloc:=LOC_VOID;
       end;


     function TInlineNode.first_get_frame: TNode;
       begin
         include(CurrentProcInfo.flags,pi_needs_stackframe);
         include(CurrentProcInfo.flags,pi_uses_get_frame);
         expectloc:=LOC_CREGISTER;
         result:=nil;
       end;


     function TInlineNode.first_setlength: TNode;
      var
        paras   : TNode;
        npara,
        ppn     : TCallParaNode;
        dims,
        counter : integer;
        isarray : boolean;
        destppn : TNode;
        newstatement : TStatementNode;
        temp    : TTempCreateNode;
        newblock : TNode;
      begin
        paras:=left;
        ppn:=TCallParaNode(paras);
        dims:=0;
        while Assigned(ppn.right) do
          begin
            inc(dims);
            ppn:=TCallParaNode(ppn.right);
          end;

        destppn:=ppn.left;
        isarray:=Is_Dynamic_Array(destppn.resultdef);
        { first param must be a string or dynamic array ...}
        if isarray then
         begin
           { SetLength(Arr, 0), Arr := nil, Arr := [] }
           if (dims=1) and is_constintvalue(TCallParaNode(paras).left, 0) then
             begin
               ppn.left:=nil; { unlink destppn }
               result:=CCallParaNode.create(CTypeConvNode.Create_Internal(destppn,VoidPointerType),nil);
               result:=CCallNode.createintern('fpc_dynarray_clear',
                 CCallParaNode.create(CAddrNode.Create_Internal(
                   CRTTINode.create(TStoredDef(destppn.resultdef),initrtti,rdt_normal)),
                 result));
               exit;
             end;
           { create statements with call initialize the arguments and
             call fpc_dynarr_setlength }
           newblock:=internalstatements(newstatement);

           { get temp for array of lengths }
           temp:=CTempCreateNode.create(CArrayDef.getreusable(SIntType,dims),dims*SIntType.Size,tt_persistent,false);
           addstatement(newstatement,temp);

           { load array of lengths }
           ppn:=TCallParaNode(paras);
           counter:=dims-1;
           while Assigned(ppn.right) do
             begin
               addstatement(newstatement,CAssignmentNode.create(
                   CVecNode.create(
                     CTempRefNode.create(temp),
                     genintconstnode(counter)
                   ),
                   ppn.left));
               ppn.left:=nil;
               dec(counter);
               ppn:=TCallParaNode(ppn.right);
             end;
           { destppn is also reused }
           ppn.left:=nil;

           { create call to fpc_dynarr_setlength }
           npara:=CCallParaNode.create(CAddrNode.Create_Internal(
                     CVecNode.create(
                       CTempRefNode.create(temp),
                       genintconstnode(0)
                     )),
                  CCallParaNode.create(COrdConstNode.create
                     (dims,SIntType,true),
                  CCallParaNode.create(CAddrNode.Create_Internal
                     (CRTTINode.create(TStoredDef(destppn.resultdef),initrtti,rdt_normal)),
                  CCallParaNode.create(CTypeConvNode.Create_Internal(destppn,VoidPointerType),nil))));
           addstatement(newstatement,CCallNode.createintern('fpc_dynarray_setlength',npara));
           addstatement(newstatement,CTempDeleteNode.create(temp));
         end
        else if Is_AnsiString(destppn.resultdef) then
         begin
            newblock:=CCallNode.createintern(
              'fpc_'+TStringDef(destppn.resultdef).StringTypName+'_setlength',
              CCallParaNode.create(
                COrdConstNode.create(GetParaEncoding(destppn.resultdef),U16IntType,true),
                paras
              )
            );
            { we reused the parameters, make sure we don't release them }
            left:=nil;
         end
        else
         begin
           { we can reuse the supplied parameters }
           newblock:=CCallNode.createintern(
              'fpc_'+TStringDef(destppn.resultdef).StringTypName+'_setlength',paras);
           { we reused the parameters, make sure we don't release them }
           left:=nil;
         end;
        result:=newblock;
      end;

    function TInlineNode.first_copy: TNode;
      var
        lowppn,
        countppn,
        elesizeppn,
        eletypeppn,
        maxcountppn,
        arrayppn,
        rttippn,
        npara,
        paras   : TNode;
        ppn     : TCallParaNode;
        paradef : TDef;
        counter : integer;
      begin
        { determine copy function to use based on the first argument,
          also count the number of arguments in this loop }
        counter:=1;
        paras:=left;
        ppn:=TCallParaNode(paras);
        while Assigned(ppn.right) do
          begin
            inc(counter);
            ppn:=TCallParaNode(ppn.right);
          end;
        paradef:=ppn.left.resultdef;

        { fill up third parameter }
        if counter=2 then
          begin
            paras:=CCallParaNode.create(COrdConstNode.create(TOrdDef(SIntType).high,SIntType,false),paras);
            counter:=3;
          end;

        if Is_AnsiString(resultdef) then
          { keep the specific kind of ansistringdef as result }
          result:=CCallNode.createinternres('fpc_ansistr_copy',paras,resultdef)
        else if Is_WideString(resultdef) then
          result:=CCallNode.createintern('fpc_widestr_copy',paras)
        else if Is_UnicodeString(resultdef) then
          result:=CCallNode.createintern('fpc_unicodestr_copy',paras)
          { can't check for resultdef = cansichartype, because resultdef=
            cshortstringtype here }
        else if Is_Char(paradef) then
          result:=CCallNode.createintern('fpc_char_copy',paras)
        else if Is_Dynamic_Array(resultdef) then
          begin
            { create statements with call }
            elesizeppn:=COrdConstNode.create(TArrayDef(paradef).EleSize,SIntType,false);
            if Is_Managed_Type(TArrayDef(paradef).ElementDef) then
              eletypeppn:=CAddrNode.Create_Internal(
                CRTTINode.create(TStoredDef(TArrayDef(paradef).ElementDef),initrtti,rdt_normal))
            else
              eletypeppn:=COrdConstNode.create(0,VoidPointerType,false);
            maxcountppn:=geninlinenode(in_length_x,false,ppn.left.GetCopy);
            case counter of
              1:
                begin
                  { copy the whole array using [0..high(sizeint)] range }
                  countppn:=COrdConstNode.create(TOrdDef(SIntType).high,SIntType,false);
                  lowppn:=COrdConstNode.create(0,SIntType,false);
                end;
              2:
                begin
                  { copy the array using [low..high(sizeint)] range }
                  countppn:=COrdConstNode.create(TOrdDef(SIntType).high,SIntType,false);
                  lowppn:=TCallParaNode(paras).left.GetCopy;
                end;
              3:
                begin
                  countppn:=TCallParaNode(paras).left.GetCopy;
                  lowppn:=TCallParaNode(TCallParaNode(paras).right).left.GetCopy;
                end;
              else
                InternalError(2012100703);
            end;

            if Is_Open_Array(paradef) then
              begin
                arrayppn:=CAddrNode.Create_Internal(ppn.left);
              end
            else if Is_Dynamic_Array(paradef) then
              begin
                arrayppn:=CTypeConvNode.Create_Internal(ppn.left,VoidPointerType);
              end
            else
              InternalError(2012100704);

            rttippn:=CAddrNode.Create_Internal(CRTTINode.create(TStoredDef(resultdef),initrtti,rdt_normal));

            { create call to fpc_array_to_dynarray_copy }
            npara:=CCallParaNode.create(eletypeppn,
                   CCallParaNode.create(elesizeppn,
                   CCallParaNode.create(maxcountppn,
                   CCallParaNode.create(countppn,
                   CCallParaNode.create(lowppn,
                   CCallParaNode.create(rttippn,
                   CCallParaNode.create(arrayppn,nil)))))));
            result:=CCallNode.createinternres('fpc_array_to_dynarray_copy',npara,resultdef);

            ppn.left:=nil;
            paras.free;
            paras := nil;
          end
        else
          result:=CCallNode.createintern('fpc_shortstr_copy',paras);
        { parameters are reused }
        left:=nil;
     end;


     function TInlineNode.first_new: TNode;
       var
         newstatement : TStatementNode;
         newblock     : TBlockNode;
         temp         : TTempCreateNode;
         para         : TCallParaNode;
       begin
         { create statements with call to getmem+initialize }
         newblock:=internalstatements(newstatement);

         { create temp for result }
         temp := CTempCreateNode.create(left.resultdef,left.resultdef.Size,tt_persistent,true);
         addstatement(newstatement,temp);

         { create call to fpc_getmem }
         para := CCallParaNode.create(COrdConstNode.create
             (TPointerDef(left.resultdef).PointedDef.Size,S32IntType,true),nil);
         addstatement(newstatement,CAssignmentNode.create(
             CTempRefNode.create(temp),
             CCallNode.createintern('fpc_getmem',para)));

         { create call to fpc_initialize }
         if Is_Managed_Type(TPointerDef(left.resultdef).PointedDef) then
          begin
            para := CCallParaNode.create(CAddrNode.Create_Internal(CRTTINode.create
                       (TStoredDef(TPointerDef(left.resultdef).PointedDef),initrtti,rdt_normal)),
                    CCallParaNode.create(CTempRefNode.create
                       (temp),nil));
            addstatement(newstatement,CCallNode.createintern('fpc_initialize',para));
          end;

         { the last statement should return the value as
           location and type, this is done be referencing the
           temp and converting it first from a persistent temp to
           normal temp }
         addstatement(newstatement,CTempDeleteNode.create_normal_temp(temp));
         addstatement(newstatement,CTempRefNode.create(temp));
         result:=newblock;
       end;


     function TInlineNode.first_length: TNode;
       begin
         result:=nil;
         if Is_ShortString(left.resultdef) then
          expectloc:=left.expectloc
         else
          begin
            { ansi/wide string }
            expectloc:=LOC_REGISTER;
          end;
       end;


     function TInlineNode.first_high: TNode;
       begin
         result:=nil;
         if not(Is_Dynamic_Array(left.resultdef)) then
           InternalError(2019122802);
         expectloc:=LOC_REGISTER;
       end;


     function TInlineNode.first_assigned: TNode;
       begin
         { Comparison must not call procvars, indicate that with nf_load_procvar flag }
         result:=CAddNode.create(unequaln,TCallParaNode(left).left,CNilNode.create);
         include(result.flags,nf_load_procvar);
         TCallParaNode(left).left:=nil;
       end;


     function TInlineNode.first_assert: TNode;
       var
         paras: TCallParaNode;
       begin
         paras:=TCallParaNode(TCallParaNode(left).right);
         paras:=CCallParaNode.create(CStringConstNode.createstr(CurrentModule.SourceFiles.Get_File_Name(CurrentFilePos.fileindex)),paras);
         paras:=CCallParaNode.create(genintconstnode(fileinfo.line),paras);
{$ifdef SUPPORT_GET_FRAME}
         paras:=CCallParaNode.create(geninlinenode(in_get_frame,false,nil),paras);
{$else}
         paras:=CCallParaNode.create(CCallNode.createinternfromunit('SYSTEM','GET_FRAME',nil),paras);
{$endif}
         result:=CIfNode.create(CNotNode.create(TCallParaNode(left).left),
            CCallNode.createintern('fpc_assert',paras),nil);
         include(result.flags,nf_internal);
         TCallParaNode(left).left:=nil;
         TCallParaNode(left).right:=nil;
       end;


     function TInlineNode.first_popcnt: TNode;
       var
         suffix : string;
       begin
         case TOrdDef(left.resultdef).OrdType of
           u8bit: suffix:='byte';
           u16bit: suffix:='word';
           u32bit: suffix:='dword';
           u64bit: suffix:='qword';
         else
           InternalError(2012082601);
         end;
         result:=CCallNode.createintern('fpc_popcnt_'+suffix,CCallParaNode.create(left,nil));
         left:=nil;
       end;

     function TInlineNode.first_bitscan: TNode;
       begin
         result:=nil;
         expectloc:=LOC_REGISTER;
       end;


     function TInlineNode.typecheck_seg: TNode;
       begin
         set_varstate(left,vs_read,[]);
         result:=COrdConstNode.create(0,S32IntType,false);
       end;


     function TInlineNode.first_seg: TNode;
       begin
         InternalError(200104046);
         result:=nil;
       end;


     function TInlineNode.first_sar: TNode;
       begin
         result:=nil;
         expectloc:=LOC_REGISTER;
{$if not defined(cpu64bitalu) and not defined(cpucg64shiftsupport)}
         if Is_64BitInt(resultdef) then
           begin
             if (inlinenumber=in_sar_x) then
               left:=CCallParaNode.create(COrdConstNode.create(1,U8IntType,false),
                 CCallParaNode.create(left,nil));
             result:=CCallNode.createintern('fpc_sarint64',left);
             left:=nil;
           end;
{$endif not defined(cpu64bitalu) and not defined(cpucg64shiftsupport)}
       end;


     function TInlineNode.handle_box: TNode;
       begin
         result:=nil;
         if not Assigned(left) or
            Assigned(TCallParaNode(left).right) then
           CGMessage1(parser_e_wrong_parameter_size,'FpcInternalBox');
         resultdef:=Class_TObject;
       end;


     function TInlineNode.handle_unbox: TNode;
       begin
         result:=nil;
         if not Assigned(left) or
            not Assigned(TCallParaNode(left).right) or
            Assigned(TCallParaNode(TCallParaNode(left).right).right) then
           CGMessage1(parser_e_wrong_parameter_size,'FpcInternalUnBox');
         if TCallParaNode(left).left.nodetype<>typen then
           InternalError(2011071701);
         TTypeNode(TCallParaNode(left).left).allowed:=true;
         resultdef:=TCallParaNode(left).left.resultdef;
       end;

     function TInlineNode.handle_insert: TNode;

       procedure do_error;
         begin
           CGMessagePos1(fileinfo,parser_e_wrong_parameter_size,'Insert');
           Write_System_Parameter_Lists('fpc_shortstr_insert');
           Write_System_Parameter_Lists('fpc_shortstr_insert_char');
           Write_System_Parameter_Lists('fpc_unicodestr_insert');
           if tf_winlikewidestring in TargetInfo.flags then
             Write_System_Parameter_Lists('fpc_widestr_insert');
           Write_System_Parameter_Lists('fpc_ansistr_insert');
           MessagePos1(fileinfo,sym_e_param_list,'Insert(Dynamic Array;var Dynamic Array;'+SIntType.TypeName+');');
           MessagePos1(fileinfo,sym_e_param_list,'Insert(Element;var Dynamic Array;'+SIntType.TypeName+');');
         end;

       var
         procname : String;
         newn,
         datan,
         datacountn,
         firstn,
         secondn : TNode;
         first,
         second : TDef;
         isconstr,
         iscomparray,
         iscompelem : boolean;
         datatemp : TTempCreateNode;
         insertblock : TBlockNode;
         insertstatement : TStatementNode;
       begin
         if not Assigned(left) or
             not Assigned(TCallParaNode(left).right) or
             not Assigned(TCallParaNode(TCallParaNode(left).right).right) or
             Assigned(TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).right) then
           begin
             do_error;
             exit(CErrorNode.create);
           end;
         { determine the correct function based on the second parameter }
         firstn:=TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).left;
         first:=firstn.resultdef;
         secondn:=TCallParaNode(TCallParaNode(left).right).left;
         second:=secondn.resultdef;
         if Is_ShortString(second) then
           begin
             if Is_Char(first) then
               procname:='fpc_shortstr_insert_char'
             else
               procname:='fpc_shortstr_insert';
           end
         else if Is_UnicodeString(second) then
           procname:='fpc_unicodestr_insert'
         else if Is_WideString(second) then
           procname:='fpc_widestr_insert'
         else if Is_AnsiString(second) then
           procname:='fpc_ansistr_insert'
         else if Is_Dynamic_Array(second) then
           begin
             { The first parameter needs to be
               a) a dynamic array of the same type
               b) a single element of the same type
               c) a static array of the same type (not Delphi compatible)
             }
             isconstr:=Is_Array_Constructor(first);
             iscomparray:=(first.typ=arraydef) and Equal_Defs(TArrayDef(first).ElementDef,TArrayDef(second).ElementDef);
             iscompelem:=Compare_Defs(first,TArrayDef(second).ElementDef,niln)<>te_incompatible;
             if not iscomparray
                 and not iscompelem
                 and not isconstr then
               begin
                 CGMessagePos(fileinfo,type_e_array_required);
                 exit(CErrorNode.create);
               end;
             insertblock:=internalstatements(insertstatement);
             datatemp:=nil;
             if iscomparray then
               begin
                 datatemp:=CTempCreateNode.create_value(first,first.Size,tt_normal,false,firstn);
                 addstatement(insertstatement,datatemp);
                 if Is_Dynamic_Array(first) then
                   datan:=CTypeConvNode.Create_Internal(CTempRefNode.create(datatemp),VoidPointerType)
                 else
                   datan:=CAddrNode.Create_Internal(CVecNode.create(CTempRefNode.create(datatemp),COrdConstNode.create(0,SizeSIntType,false)));
                 datacountn:=CInlineNode.create(in_length_x,false,CTempRefNode.create(datatemp));
               end
             else if isconstr then
               begin
                 inserttypeconv(firstn,second);
                 datatemp:=CTempCreateNode.create_value(second,second.Size,tt_normal,false,firstn);
                 addstatement(insertstatement,datatemp);
                 datan:=CTypeConvNode.Create_Internal(CTempRefNode.create(datatemp),VoidPointerType);
                 datacountn:=CInlineNode.create(in_length_x,false,CTempRefNode.create(datatemp));
               end
             else
               begin
                 if is_const(firstn) then
                   begin
                     datatemp:=CTempCreateNode.create_value(TArrayDef(second).ElementDef,TArrayDef(second).ElementDef.Size,tt_normal,false,firstn);
                     addstatement(insertstatement,datatemp);
                     datan:=CAddrNode.Create_Internal(CTempRefNode.create(datatemp));
                   end
                 else
                   begin
                     datan:=firstn;
                     inserttypeconv(datan,TArrayDef(second).ElementDef);
                     datan:=CAddrNode.Create_Internal(datan);
                   end;
                 datacountn:=COrdConstNode.create(1,SizeSIntType,false);
               end;
             procname:='fpc_dynarray_insert';
             { recreate the parameters as array pointer, source, data, count, typeinfo }
             newn:=CCallParaNode.create(CAddrNode.Create_Internal(CRTTINode.create(TStoredDef(second),initrtti,rdt_normal)),
                     CCallParaNode.create(datacountn,
                       CCallParaNode.create(datan,
                         CCallParaNode.create(TCallParaNode(left).left,
                           CCallParaNode.create(CTypeConvNode.Create_Internal(secondn,VoidPointerType),nil)))));
             addstatement(insertstatement,CCallNode.createintern(procname,newn));
             if Assigned(datatemp) then
               addstatement(insertstatement,CTempDeleteNode.create(datatemp));
             TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).left:=nil; // insert idx
             TCallParaNode(TCallParaNode(left).right).left:=nil; // dyn array
             TCallParaNode(left).left:=nil; // insert element/array
             left.free;
             left:=nil;
             result:=insertblock;
             exit; { ! }
           end
         else if second.typ=undefineddef then
           { just pick one }
           procname:='fpc_ansistr_insert'
         else
           begin
             do_error;
             exit(CErrorNode.create);
           end;
         result:=CCallNode.createintern(procname,left);
         left:=nil;
       end;

     function TInlineNode.handle_delete: TNode;

       procedure do_error;
         begin
           CGMessagePos1(fileinfo,parser_e_wrong_parameter_size,'Delete');
           Write_System_Parameter_Lists('fpc_shortstr_delete');
           Write_System_Parameter_Lists('fpc_unicodestr_delete');
           if tf_winlikewidestring in TargetInfo.flags then
             Write_System_Parameter_Lists('fpc_widestr_delete');
           Write_System_Parameter_Lists('fpc_ansistr_delete');
           MessagePos1(fileinfo,sym_e_param_list,'Delete(var Dynamic Array;'+SIntType.TypeName+';'+SIntType.TypeName+');');
         end;

       var
         procname : String;
         first : TDef;
         firstn,
         newn : TNode;
       begin
         if not Assigned(left) or
             not Assigned(TCallParaNode(left).right) or
             not Assigned(TCallParaNode(TCallParaNode(left).right).right) or
             Assigned(TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).right) then
           begin
             do_error;
             exit(CErrorNode.create);
           end;
         { determine the correct function based on the first parameter }
         firstn:=TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).left;
         first:=firstn.resultdef;
         if Is_ShortString(first) then
           procname:='fpc_shortstr_delete'
         else if Is_UnicodeString(first) then
           procname:='fpc_unicodestr_delete'
         else if Is_WideString(first) then
           procname:='fpc_widestr_delete'
         else if Is_AnsiString(first) then
           procname:='fpc_ansistr_delete'
         else if Is_Dynamic_Array(first) then
           begin
             procname:='fpc_dynarray_delete';
             { recreate the parameters as array pointer, src, count, typeinfo }
             newn:=CCallParaNode.create(CAddrNode.Create_Internal
                  (CRTTINode.create(TStoredDef(first),initrtti,rdt_normal)),
                    CCallParaNode.create(TCallParaNode(left).left,
                      CCallParaNode.create(TCallParaNode(TCallParaNode(left).right).left,
                        CCallParaNode.create(CTypeConvNode.Create_Internal(firstn,VoidPointerType),nil))));
             TCallParaNode(TCallParaNode(TCallParaNode(left).right).right).left:=nil;
             TCallParaNode(TCallParaNode(left).right).left:=nil;
             TCallParaNode(left).left:=nil;
             left.free;
             left:=newn;
           end
         else if first.typ=undefineddef then
           { just pick one }
           procname:='fpc_ansistr_delete'
         else
           begin
             do_error;
             exit(CErrorNode.create);
           end;
         result:=CCallNode.createintern(procname,left);
         left:=nil;
       end;


     function TInlineNode.handle_concat:TNode;

       procedure do_error;
         begin
           CGMessagePos1(fileinfo,parser_e_wrong_parameter_size,'Concat');
           MessagePos1(fileinfo,sym_e_param_list,'Concat(String[;String;...])');
           MessagePos1(fileinfo,sym_e_param_list,'Concat(Dynamic Array[;Dynamic Array;...])');
         end;

       var
         cpn : TCallParaNode;
         list : TFPObjectList;
         n,
         arrn,
         firstn : TNode;
         i : LongInt;
         arrconstr : TArrayConstructorNode;
         newstatement : TStatementNode;
         tempnode : TTempCreateNode;
         lastchanged : boolean;
       begin
         if not Assigned(left) then
           begin
             do_error;
             exit(CErrorNode.create);
           end;
         result:=nil;
         { the arguments are right to left, but we need to work on them from
           left to right, so insert them in a list and process that from back
           to front }
         list:=TFPObjectList.create(false);
         { remember the last (aka first) dynamic array parameter (important
           in case of array constructors) }
         arrn:=nil;
         cpn:=TCallParaNode(left);
         while Assigned(cpn) do
           begin
             list.add(cpn.left);
             if Is_Dynamic_Array(cpn.left.resultdef) then
               arrn:=cpn.left;
             cpn.left:=nil;
             cpn:=TCallParaNode(cpn.right);
           end;

         if list.count=0 then
           InternalError(2017100901);

         firstn:=TNode(list.last);
         if not Assigned(firstn) then
           InternalError(2017100902);

         { are we dealing with strings or dynamic arrays? }
         if Is_Dynamic_Array(firstn.resultdef) or Is_Array_Constructor(firstn.resultdef) then
           begin
             { try to combine all consecutive array constructors }
             lastchanged:=false;
             i:=0;
             repeat
               if lastchanged or Is_Array_Constructor(TNode(list[i]).resultdef) then
                 begin
                   if (i<list.count-1) and Is_Array_Constructor(TNode(list[i+1]).resultdef) then
                     begin
                       arrconstr:=TArrayConstructorNode(list[i+1]);
                       while Assigned(arrconstr.right) do
                         arrconstr:=TArrayConstructorNode(arrconstr.right);
                       arrconstr.right:=TNode(list[i]);
                       list[i]:=list[i+1];
                       list.delete(i+1);
                       lastchanged:=true;
                       TNode(list[i]).resultdef:=nil;
                       { don't increase index! }
                       continue;
                     end;
                   if lastchanged then
                     begin
                       { we concatenated all consecutive ones, so typecheck the new one again }
                       n:=TNode(list[i]);
                       TypeCheckPass(n);
                       list[i]:=n;
                     end;
                   lastchanged:=false;
                 end;
               inc(i);
             until i=list.count;

             if list.count=1 then
               begin
                 { no need to call the concat helper }
                 result:=firstn;
               end
             else
               begin
                 { if we reach this point then the concat list didn't consist
                   solely of array constructors }
                 if not Assigned(arrn) then
                   InternalError(2017101001);

                 result:=internalstatements(newstatement);

                 { generate the open array constructor for the source arrays
                   note: the order needs to be swapped again here! }
                 arrconstr:=nil;
                 for i:=0 to list.count-1 do
                   begin
                     n:=TNode(list[i]);
                     { first convert to the target type }
                     if not Is_Array_Constructor(n.resultdef) then
                       inserttypeconv(n,arrn.resultdef);
                     { we need to ensure that we get a reference counted
                       assignment for the temp array }
                     tempnode:=CTempCreateNode.create(arrn.resultdef,arrn.resultdef.Size,tt_persistent,true);
                     addstatement(newstatement,tempnode);
                     addstatement(newstatement,CAssignmentNode.create(CTempRefNode.create(tempnode),n));
                     addstatement(newstatement,CTempDeleteNode.create_normal_temp(tempnode));
                     n:=CTempRefNode.create(tempnode);
                     { then to a plain pointer for the helper }
                     inserttypeconv_internal(n,VoidPointerType);
                     arrconstr:=CArrayConstructorNode.create(n,arrconstr);
                   end;
                 Include(arrconstr.arrayconstructornodeflags,acnf_allow_array_constructor);

                 { based on the code from nopt.genmultistringadd() }
                 tempnode:=CTempCreateNode.create(arrn.resultdef,arrn.resultdef.Size,tt_persistent,true);
                 addstatement(newstatement,tempnode);

                 cpn:=CCallParaNode.create(
                         arrconstr,
                         CCallParaNode.create(
                           CAddrNode.Create_Internal(CRTTINode.create(TStoredDef(arrn.resultdef),initrtti,rdt_normal)),
                             CCallParaNode.create(CTypeConvNode.Create_Internal(CTempRefNode.create(tempnode),VoidPointerType),nil))
                       );
                 addstatement(
                   newstatement,
                   CCallNode.createintern(
                     'fpc_dynarray_concat_multi',
                     cpn
                   )
                 );
                 addstatement(newstatement,CTempDeleteNode.create_normal_temp(tempnode));
                 addstatement(newstatement,CTempRefNode.create(tempnode));
               end;
           end
         else
           begin
             { enforce strings }
             for i:=list.count-1 downto 0 do
               begin
                 if Assigned(result) then
                   result:=CAddNode.create(addn,result,TNode(list[i]))
                 else
                   begin
                     result:=TNode(list[i]);
                     { Force string type if it isn't yet }
                     if not(
                            (result.resultdef.typ=stringdef) or
                            Is_CharArray(result.resultdef) or
                            Is_Char(result.resultdef)
                           ) then
                       inserttypeconv(result,CShortStringType);
                   end;
               end;
           end;

         list.free;
         list := nil;
       end;


     function TInlineNode.first_pack_unpack: TNode;
       var
         loopstatement    : TStatementNode;
         loop             : TBlockNode;
         loopvar          : TTempCreateNode;
         tempnode,
         source,
         target,
         index,
         unpackednode,
         packednode,
         sourcevecindex,
         targetvecindex,
         loopbody         : TNode;
         temprangedef     : TDef;
         ulorange,
         uhirange,
         plorange,
         phirange          : TConstExprInt;
       begin
         { transform into a for loop which assigns the data of the (un)packed }
         { array to the other one                                             }
         source := left;
         if (inlinenumber = in_unpack_x_y_z) then
           begin
             target := TCallParaNode(source).right;
             index := TCallParaNode(target).right;
             packednode := TCallParaNode(source).left;
             unpackednode := TCallParaNode(target).left;
           end
         else
           begin
             index := TCallParaNode(source).right;
             target := TCallParaNode(index).right;
             packednode := TCallParaNode(target).left;
             unpackednode := TCallParaNode(source).left;
           end;
         source := TCallParaNode(source).left;
         target := TCallParaNode(target).left;
         index := TCallParaNode(index).left;

         loop := internalstatements(loopstatement);
         loopvar := CTempCreateNode.create(
           TArrayDef(packednode.resultdef).RangeDef,
           TArrayDef(packednode.resultdef).RangeDef.Size,
           tt_persistent,true);
         addstatement(loopstatement,loopvar);

         { For range checking: we have to convert to an integer type (in case the index type }
         { is an enum), add the index and loop variable together, convert the result         }
         { implicitly to an orddef with range equal to the rangedef to get range checking   }
         { and finally convert it explicitly back to the actual rangedef to avoid type      }
         { errors                                                                            }
         temprangedef:=nil;
         GetRange(unpackednode.resultdef,ulorange,uhirange);
         GetRange(packednode.resultdef,plorange,phirange);
         { does not really need to be registered, but then we would have to
           record it elsewhere so it still can be freed }
         temprangedef:=COrdDef.create(TOrdDef(SIntType).OrdType,ulorange,uhirange,true);
         sourcevecindex := CTempRefNode.create(loopvar);
         targetvecindex := CTypeConvNode.Create_Internal(index.GetCopy,SIntType);
         targetvecindex := CAddNode.create(subn,targetvecindex,COrdConstNode.create(plorange,SIntType,true));
         targetvecindex := CAddNode.create(addn,targetvecindex,CTempRefNode.create(loopvar));
         targetvecindex := CTypeConvNode.create(targetvecindex,temprangedef);
         targetvecindex := CTypeConvNode.create_explicit(targetvecindex,TArrayDef(unpackednode.resultdef).RangeDef);

         if (inlinenumber = in_pack_x_y_z) then
           begin
             { swap source and target vec indices }
             tempnode := sourcevecindex;
             sourcevecindex := targetvecindex;
             targetvecindex := tempnode;
           end;

         { create the assignment in the loop body }
         loopbody :=
           CAssignmentNode.create(
             CVecNode.create(target.GetCopy,targetvecindex),
             CVecNode.create(source.GetCopy,sourcevecindex)
           );
         { create the actual for loop }
         tempnode := CForNode.create(
           CTempRefNode.create(loopvar),
           CInlineNode.create(in_low_x,false,packednode.GetCopy),
           CInlineNode.create(in_high_x,false,packednode.GetCopy),
           loopbody,
           false);
         addstatement(loopstatement,tempnode);
         { free the loop counter }
         addstatement(loopstatement,CTempDeleteNode.create(loopvar));
         result := loop;
       end;

     function TInlineNode.may_have_sideeffect_norecurse: boolean;
       begin
         result:=
          (inlinenumber in [in_write_x,in_writeln_x,in_read_x,in_readln_x,in_str_x_string,
           in_val_x,in_reset_x,in_rewrite_x,in_reset_typedfile,in_rewrite_typedfile,
           in_reset_typedfile_name,in_rewrite_typedfile_name,in_settextbuf_file_x,
           in_inc_x,in_dec_x,in_include_x_y,in_exclude_x_y,in_break,in_continue,in_setlength_x,
           in_finalize_x,in_new_x,in_dispose_x,in_exit,in_copy_x,in_initialize_x,in_leave,in_cycle,
           in_and_assign_x_y,in_or_assign_x_y,in_xor_assign_x_y,in_sar_assign_x_y,in_shl_assign_x_y,
           in_shr_assign_x_y,in_rol_assign_x_y,in_ror_assign_x_y,in_neg_assign_x,in_not_assign_x]) or
          ((inlinenumber = in_assert_x_y) and
           (cs_do_assertion in LocalSwitches));
       end;


     function TInlineNode.may_ignore_result:boolean;
       begin
         case inlinenumber of
           in_atomic_inc,
           in_atomic_dec,
           in_atomic_xchg,
           in_atomic_cmp_xchg:
             result:=true;
           else
             result:=Is_Void(resultdef);
         end;
       end;


     function TInlineNode.first_fma: TNode;
       begin
         CGMessage1(cg_e_function_not_support_by_selected_instruction_set,'FMA');
         result:=nil;
       end;


     function TInlineNode.first_minmax: TNode;
       begin
         CGMessage1(cg_e_function_not_support_by_selected_instruction_set,'MIN/MAX');
         result:=nil;
       end;


{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
     function TInlineNode.first_ShiftRot_assign_64bitint: TNode;
       var
         procname: string[31];
       begin
{$ifdef cpucg64shiftsupport}
         if inlinenumber in [in_sar_assign_x_y,in_shl_assign_x_y,in_shr_assign_x_y] then
           begin
             result:=nil;
             expectloc:=TCallParaNode(TCallParaNode(left).right).left.expectloc;
             exit;
           end;
{$endif cpucg64shiftsupport}
         result := nil;
         if Is_Signed(TCallParaNode(left).right.resultdef) then
           procname:='int64'
         else
           procname:='qword';
         case inlinenumber of
           in_sar_assign_x_y:
             procname := 'fpc_sar_assign_'+procname;
           in_shl_assign_x_y:
             procname := 'fpc_shl_assign_'+procname;
           in_shr_assign_x_y:
             procname := 'fpc_shr_assign_'+procname;
           in_rol_assign_x_y:
             procname := 'fpc_rol_assign_'+procname;
           in_ror_assign_x_y:
             procname := 'fpc_ror_assign_'+procname;
           else
             InternalError(2017041301);
         end;
         result := CCallNode.createintern(procname,CCallParaNode.create(TCallParaNode(left).left,
           CCallParaNode.create(TCallParaNode(TCallParaNode(left).right).left,nil)));
         TCallParaNode(TCallParaNode(left).right).left := nil;
         TCallParaNode(left).left := nil;
         FirstPass(result);
       end;
{$endif not cpu64bitalu and nto cpuhighleveltarget}


     function TInlineNode.first_AndOrXorShiftRot_assign: TNode;
       begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         { 64 bit ints have their own shift handling }
         if Is_64Bit(TCallParaNode(left).right.resultdef) and
            (inlinenumber in [in_sar_assign_x_y,in_shl_assign_x_y,in_shr_assign_x_y,in_rol_assign_x_y,in_ror_assign_x_y]) then
           result := first_ShiftRot_assign_64bitint
         else
{$endif not cpu64bitalu and not cpuhighleveltarget}
           begin
             result:=nil;
             expectloc:=TCallParaNode(TCallParaNode(left).right).left.expectloc;
           end;
       end;


     function TInlineNode.first_NegNot_assign: TNode;
       begin
         result:=nil;
         expectloc:=left.expectloc;
       end;


     function TInlineNode.first_atomic: TNode;
       var
         name : string;
         n,n2,cmpn,succn,valn : TNode;
         c : sizeint;
         stmt : TStatementNode;
         tmp,tmp2: TTempCreateNode;
       begin
         { by default we redirect to the corresponding compilerprocs }
         name:='fpc_atomic_';
         case inlinenumber of
           in_atomic_inc:
             if Assigned(TCallParaNode(left).right) then
               name:=name+'add'
             else
               name:=name+'inc';
           in_atomic_dec:
             if Assigned(TCallParaNode(left).right) then
               name:=name+'sub'
             else
               name:=name+'dec';
           in_atomic_xchg:
             name:=name+'xchg';
           in_atomic_cmp_xchg:
             name:=name+'cmp_xchg';
           else
             InternalError(2022093008);
         end;
         name:=name+'_';
         if Is_Pointer(resultdef) then
           name:=name+ToStr(VoidPointerType.Size*8)
         else if Is_Integer(resultdef) then
           case TOrdDef(resultdef).OrdType of
             s8bit:
               name:=name+'8';
             s16bit:
               name:=name+'16';
             s32bit:
               name:=name+'32';
             s64bit:
               name:=name+'64';
             else
               InternalError(2022100101);
           end
         else
           InternalError(2022093009);

         { for the call node we need to reverse the parameters }
         c:=reverseparameters(TCallParaNode(left));

         succn:=nil;
         cmpn:=nil;
         valn:=nil;

         if (inlinenumber=in_atomic_cmp_xchg) and (c=4) then
           begin
             { don't pass along the Succeeded parameter }
             succn:=TCallParaNode(left).left;
             n:=TCallParaNode(left).right;
             TCallParaNode(left).left:=nil;
             TCallParaNode(left).right:=nil;
             left.free;
             left:=TCallParaNode(n);
             { get a copy of the Comparand parameter }
             cmpn:=TCallParaNode(left).left.GetCopy;
           end
         else if ((inlinenumber=in_atomic_inc) or (inlinenumber=in_atomic_dec)) and (c=2) then
           begin
             valn:=TCallParaNode(left).left.GetCopy;
           end;

         result:=CTypeConvNode.Create_Internal(CCallNode.createintern(name,left),resultdef);

         left:=nil;

         if Assigned(succn) then
           begin
             { we need to execute the intrinsic and then we check whether the
               returned result, namely the original value, is equal to the
               comparand which means that the Succeeded parameter needs to be
               True (otherwise it needs to be False). }
             n:=internalstatements(stmt);
             tmp:=CTempCreateNode.create(resultdef,resultdef.Size,tt_persistent,true);
             addstatement(stmt,tmp);
             addstatement(stmt,CAssignmentNode.create(CTempRefNode.create(tmp),result));
             cmpn:=cmpn.GetCopy;
             inserttypeconv_internal(cmpn,resultdef);
             addstatement(stmt,
               CAssignmentNode.create(succn,
                 CAddNode.create(EqualN,cmpn,
                   CTempRefNode.create(tmp))));
             addstatement(stmt,CTempDeleteNode.create_normal_temp(tmp));
             addstatement(stmt,CTempRefNode.create(tmp));
             result:=n;
           end
         else if ((inlinenumber=in_atomic_dec) or (inlinenumber=in_atomic_inc)) and (c=2) then
           begin
             { the helpers return the original value, due to ease of implementation with the
               existing Interlocked* implementations, but the intrinsics need to return the
               resulting value so we add/sub the Value to/from the result }
             n:=internalstatements(stmt);
             tmp:=CTempCreateNode.create(resultdef,resultdef.Size,tt_persistent,true);
             addstatement(stmt,tmp);
             if inlinenumber=in_atomic_inc then
               n2:=CAddNode.create(addn,result,valn)
             else
               n2:=CAddNode.create(subn,result,valn);
             addstatement(stmt,CAssignmentNode.create(CTempRefNode.create(tmp),n2));
             addstatement(stmt,CTempDeleteNode.create_normal_temp(tmp));
             addstatement(stmt,CTempRefNode.create(tmp));
             result:=n;
           end;
       end;


     function TInlineNode.first_cpu : TNode;
       begin
         Result:=nil;
         InternalError(2017110101);
       end;


     procedure TInlineNode.CheckParameters(count: integer);
       var
         p: TNode;
       begin
         if count=1 then
           begin
             // Sometimes there are more callparanodes
             if left is TCallParaNode then
               set_varstate(TCallParaNode(left).left,vs_read,[vsf_must_be_valid])
             else
               set_varstate(left,vs_read,[vsf_must_be_valid])
           end
         else
           begin
             p:=left;
             while count>0 do
               begin
                 set_varstate(TCallParaNode(p).left,vs_read,[vsf_must_be_valid]);

                 p:=TCallParaNode(p).right;
                 dec(count);
               end;
           end;
       end;

end.

