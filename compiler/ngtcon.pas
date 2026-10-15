{
    Copyright (c) 1998-2011 by Florian Klaempfl, Jonas Maebe

    Generates code/nodes for typed constant declarations

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
unit ngtcon;

{$i fpcdefs.inc}

interface

    uses
      TPCompilerReal,
      GlobType,CClasses,ConstExp,
      aasmbase,AAsmData,aasmtai,aasmcnst,
      node,nbas,
      symconst, symtype, SymBase, symdef,SymSym;


    type
      TTypedConstBuilder = class
       protected
        current_old_block_type : TBlockType;
        tcsym: TStaticVarSym;

        { this procedure reads typed constants }
        procedure read_typed_const_data(def:TDef);

        procedure parse_orddef(def: TOrdDef);
        procedure parse_floatdef(def: TFloatDef);
        procedure parse_classrefdef(def: TClassRefDef);
        procedure parse_pointerdef(def: TPointerDef);
        procedure parse_setdef(def: TSetDef);
        procedure parse_enumdef(def: TEnumDef);
        procedure parse_stringdef(def: TStringDef);
        procedure parse_arraydef(def:TArrayDef);virtual;abstract;
        procedure parse_procvardef(def:TProcVarDef);virtual;abstract;
        procedure parse_recorddef(def:TRecordDef);virtual;abstract;
        procedure parse_objectdef(def:TObjectDef);virtual;abstract;

        procedure tc_emit_orddef(def: TOrdDef; var node: TNode);virtual;abstract;
        procedure tc_emit_floatdef(def: TFloatDef; var node: TNode);virtual;abstract;
        procedure tc_emit_classrefdef(def: TClassRefDef; var node: TNode);virtual;abstract;
        procedure tc_emit_pointerdef(def: TPointerDef; var node: TNode);virtual;abstract;
        procedure tc_emit_setdef(def: TSetDef; var node: TNode);virtual;abstract;
        procedure tc_emit_enumdef(def: TEnumDef; var node: TNode);virtual;abstract;
        procedure tc_emit_stringdef(def: TStringDef; var node: TNode);virtual;abstract;
       public
        constructor create(sym: TStaticVarSym);
      end;
      TTypedConstBuilderClass = class of TTypedConstBuilder;


      { should be changed into nested type of tasmlisttypedconstbuilder when
        possible }
      TBitPackedVal = record
        curval, nextval: aword;
        curbitoffset: smallint;
        PackedBitSize: byte;
      end;

      TAsmListTypedConstBuilder = class(TTypedConstBuilder)
       private
        fsym: TStaticVarSym;
        curoffset: asizeint;

        function parse_single_packed_const(def: TDef; var bp: TBitPackedVal): boolean;
        procedure flush_packed_value(var bp: TBitPackedVal);
       protected
        ftcb: TTAITypedConstBuilder;
        fdatalist: TAsmList;

        procedure parse_packed_array_def(def: TArrayDef);
        procedure parse_arraydef(def:TArrayDef);override;
        procedure parse_procvardef(def:TProcVarDef);override;
        procedure parse_recorddef(def:TRecordDef);override;
        procedure parse_objectdef(def:TObjectDef);override;

        procedure tc_emit_orddef(def: TOrdDef; var node: TNode);override;
        procedure tc_emit_floatdef(def: TFloatDef; var node: TNode); override;
        procedure tc_emit_classrefdef(def: TClassRefDef; var node: TNode);override;
        procedure tc_emit_pointerdef(def: TPointerDef; var node: TNode);override;
        procedure tc_emit_setdef(def: TSetDef; var node: TNode);override;
        procedure tc_emit_enumdef(def: TEnumDef; var node: TNode);override;
        procedure tc_emit_stringdef(def: TStringDef; var node: TNode);override;
       public
        constructor create(sym: TStaticVarSym);virtual;
        destructor Destroy; override;
        procedure parse_into_asmlist;
        { the asmlist containing the definition of the parsed entity and another
          one containing the data generated for that same entity (e.g. the
          string data referenced by an ansistring constant) }
        procedure get_final_asmlists(out reslist, datalist: TAsmList);
      end;
      TAsmListTypedConstBuilderClass = class of TAsmListTypedConstBuilder;

      TNodeTreeTypedConstBuilder = class(TTypedConstBuilder)
       protected
        resultblock: TBlockNode;
        statmnt: TStatementNode;

        { when parsing a record, the base nade becomes a loadnode of the record,
          etc. }
        basenode: TNode;

        procedure parse_arraydef(def:TArrayDef);override;
        procedure parse_procvardef(def:TProcVarDef);override;
        procedure parse_recorddef(def:TRecordDef);override;
        procedure parse_objectdef(def:TObjectDef);override;

        procedure tc_emit_orddef(def: TOrdDef; var node: TNode);override;
        procedure tc_emit_floatdef(def: TFloatDef; var node: TNode); override;
        procedure tc_emit_classrefdef(def: TClassRefDef; var node: TNode);override;
        procedure tc_emit_pointerdef(def: TPointerDef; var node: TNode);override;
        procedure tc_emit_setdef(def: TSetDef; var node: TNode);override;
        procedure tc_emit_enumdef(def: TEnumDef; var node: TNode);override;
        procedure tc_emit_stringdef(def: TStringDef; var node: TNode);override;
       public
        constructor create(sym: TStaticVarSym; previnit: TNode);virtual;
        destructor Destroy;override;
        function parse_into_nodetree: TNode;
      end;
      TNodeTreeTypedConstBuilderClass = class of TNodeTreeTypedConstBuilder;

   var
     CTypedConstBuilder: TTypedConstBuilderClass;

implementation

uses
   SysUtils,
   Systems,tokens,Verbose,compinnr,
   CUtils,Globals,WideStr,Scanner,
   SymTable,
   defutil,defcmp,
   { pass 1 }
   htypechk,ProcInfo,pass_1,
   nmem,ncnv,ninl,ncon,nld,nadd,
   { parser specific stuff }
   pbase,pexpr,
   { codegen }
   CPUInfo,cgbase,
   wpobase
   ;

{$maxfpuregisters 0}

function get_next_varsym(def: TAbstractRecordDef; const SymList:TFPHashObjectList; var symidx:LongInt):TSym;inline;
  begin
    while symidx<SymList.Count do
      begin
        result:=TSym(def.SymTable.SymList[symidx]);
        inc(symidx);
        if (result.typ=FieldVarSym) and
           not(sp_static in result.SymOptions) then
          exit;
      end;
    result:=nil;
  end;


{*****************************************************************************
                             read typed const
*****************************************************************************}

      procedure TTypedConstBuilder.parse_orddef(def:TOrdDef);
        var
          n : TNode;
        begin
           n:=comp_expr([ef_accept_equal]);
           { for C-style booleans, true=-1 and false=0) }
           if is_cbool(def) then
             inserttypeconv(n,def);
           tc_emit_orddef(def,n);
           n.free;
           n := nil;
        end;

      procedure TTypedConstBuilder.parse_floatdef(def:TFloatDef);
        var
          n : TNode;
        begin
          n:=comp_expr([ef_accept_equal]);
          tc_emit_floatdef(def,n);
          n.free;
          n := nil;
        end;

      procedure TTypedConstBuilder.parse_classrefdef(def:TClassRefDef);
        var
          n : TNode;
        begin
          n:=comp_expr([ef_accept_equal]);
          case n.nodetype of
            loadvmtaddrn:
              begin
                { update wpo info }
                if wpoinfomanager.symbol_live_in_currentproc(n.resultdef) then
                  TObjectDef(TClassRefDef(n.resultdef).PointedDef).Register_Maybe_Created_Object_Type;
              end;
            else
              ;
          end;
          tc_emit_classrefdef(def,n);
          n.free;
          n := nil;
        end;

      procedure TTypedConstBuilder.parse_pointerdef(def:TPointerDef);
        var
          p: TNode;
        begin
          p:=comp_expr([ef_accept_equal]);
          tc_emit_pointerdef(def,p);
          p.free;
          p := nil;
        end;

      procedure TTypedConstBuilder.parse_setdef(def:TSetDef);
        var
          p : TNode;
        begin
          p:=comp_expr([ef_accept_equal]);
          tc_emit_setdef(def,p);
          p.free;
          p := nil;
        end;

      procedure TTypedConstBuilder.parse_enumdef(def:TEnumDef);
        var
          p : TNode;
        begin
          p:=comp_expr([ef_accept_equal]);
          tc_emit_enumdef(def,p);
          p.free;
          p := nil;
        end;

      procedure TTypedConstBuilder.parse_stringdef(def:TStringDef);
        var
          n : TNode;
        begin
          n:=comp_expr([ef_accept_equal]);
          tc_emit_stringdef(def,n);
          n.free;
          n := nil;
        end;

    { ttypedconstbuilder }

    procedure TTypedConstBuilder.read_typed_const_data(def:TDef);
      var
       prev_old_block_type,
       old_block_type: TBlockType;
      begin
        old_block_type:=Block_Type;
        prev_old_block_type:=current_old_block_type;
        current_old_block_type:=old_block_type;
        Block_Type:=bt_const;
        case def.typ of
          orddef :
            parse_orddef(TOrdDef(def));
          floatdef :
            parse_floatdef(TFloatDef(def));
          classrefdef :
            parse_classrefdef(TClassRefDef(def));
          pointerdef :
            parse_pointerdef(TPointerDef(def));
          setdef :
            parse_setdef(TSetDef(def));
          enumdef :
            parse_enumdef(TEnumDef(def));
          stringdef :
            parse_stringdef(TStringDef(def));
          arraydef :
            parse_arraydef(TArrayDef(def));
          procvardef:
            parse_procvardef(TProcVarDef(def));
          recorddef:
            parse_recorddef(TRecordDef(def));
          objectdef:
            parse_objectdef(TObjectDef(def));
          errordef:
            begin
               { try to consume something useful }
               if CurrentScanner.token=_LKLAMMER then
                 consume_all_until(_RKLAMMER)
               else
                 consume_all_until(_SEMICOLON);
            end;
          else
            Message(parser_e_type_const_not_possible);
        end;
        Block_Type:=old_block_type;
        current_old_block_type:=prev_old_block_type;
      end;


    constructor TTypedConstBuilder.create(sym: TStaticVarSym);
      begin
        tcsym:=sym;
      end;


{*****************************************************************************
                          Bitpacked value helpers
*****************************************************************************}

    procedure initbitpackval(out bp: TBitPackedVal; PackedBitSize: byte);
      begin
        bp.curval:=0;
        bp.nextval:=0;
        bp.curbitoffset:=0;
        bp.PackedBitSize:=PackedBitSize;
      end;


{$push}
{$r-}
{$q-}
    { to work around broken x86 shifting, while generating bitmask }
    function getbitmask(len: byte): aword;
      begin
        if len >= (sizeof(result) * 8) then
          result:=0
        else
          result:=aword(1) shl len;
        result:=aword(result-1);
      end;

    { shift left, and always pad the right bits with zeroes }
    function shiftleft(value: aword; count: byte): aword;
      begin
        if count >= (sizeof(result) * 8) then
          result:=0
        else
          result:=(value shl count) and (not getbitmask(count));
      end;

    { (values between quotes below refer to fields of bp; fields not         }
    {  mentioned are unused by this routine)                                 }
    { bitpacks "value" as bitpacked value of bitsize "packedbitsize" into    }
    { "curval", which has already been filled up to "curbitoffset", and      }
    { stores the spillover if any into "nextval". It also updates            }
    { curbitoffset to reflect how many bits of currval are now used (can be  }
    { > AIntBits in case of spillover)                                       }
    procedure bitpackval(value: aword; var bp: TBitPackedVal);
      var
        shiftcount: LongInt;
      begin
        if (TargetInfo.endian=endian_big) then
          begin
            { bitpacked format: left-aligned (i.e., "big endian bitness") }
            if (bp.PackedBitSize<AIntBits) and
               (bp.curbitoffset<AIntBits) then
              bp.curval:=bp.curval or (shiftleft(value,AIntBits-bp.PackedBitSize) shr bp.curbitoffset);
            shiftcount:=((AIntBits-bp.PackedBitSize)-bp.curbitoffset);
            { carry-over to the next element? }
            if (shiftcount<0) then
              begin
                if shiftcount>=-AIntBits then
                  bp.nextval:=(value and getbitmask(-shiftcount)) shl
                              (AIntBits+shiftcount)
                else
                  bp.nextval:=0;
              end
          end
        else
          begin
            { bitpacked format: right aligned (i.e., "little endian bitness") }
            { work around broken x86 shifting }
            if bp.curbitoffset<AIntBits then
              bp.curval:=bp.curval or (value shl bp.curbitoffset);
            { carry-over to the next element? }
            if (bp.curbitoffset+bp.PackedBitSize>AIntBits) then
              if bp.curbitoffset>0 then
                bp.nextval:=value shr (AIntBits-bp.curbitoffset)
              else
                bp.nextval:=0;
          end;
        inc(bp.curbitoffset,bp.PackedBitSize);
      end;

    procedure TAsmListTypedConstBuilder.flush_packed_value(var bp: TBitPackedVal);
      var
        bitstowrite: LongInt;
        writeval : aint;
      begin
        if (bp.curbitoffset < AIntBits) then
          begin
            { forced flush -> write multiple of a byte }
            bitstowrite:=align(bp.curbitoffset,8);
            bp.curbitoffset:=0;
          end
        else
          begin
            bitstowrite:=AIntBits;
            dec(bp.curbitoffset,AIntBits);
          end;
        while (bitstowrite>=8) do
          begin
            if (TargetInfo.endian=endian_little) then
              begin
                { write lowest byte }
                writeval:=byte(bp.curval);
                bp.curval:=bp.curval shr 8;
              end
            else
              begin
                { write highest byte }
                writeval:=bp.curval shr (AIntBits-8);
{$push}{$r-,q-}
                bp.curval:=bp.curval shl 8;
{$pop}
              end;
            ftcb.emit_tai(TAIConst.create_8bit(writeval),U8IntType);
            dec(bitstowrite,8);
          end;
        bp.curval:=bp.nextval;
        bp.nextval:=0;
      end;

    {$pop}


    { parses a packed array constant }
    procedure TAsmListTypedConstBuilder.parse_packed_array_def(def: TArrayDef);
      var
        i  : aint;
        bp : TBitPackedVal;
      begin
        if not(def.ElementDef.typ in [orddef,enumdef]) then
          InternalError(2007022010);
        ftcb.maybe_begin_aggregate(def);
        { begin of the array }
        consume(_LKLAMMER);
        initbitpackval(bp,def.ElePackedBitSize);
        i:=def.LowRange;
        { can't use for-loop, fails when cross-compiling from }
        { 32 to 64 bit because i is then 64 bit               }
        while (i<def.HighRange) do
          begin
            { get next item of the packed array }
            if not parse_single_packed_const(def.ElementDef,bp) then
              exit;
            consume(_COMMA);
            inc(i);
          end;
        { final item }
        if not parse_single_packed_const(def.ElementDef,bp) then
          exit;
        { flush final incomplete value if necessary }
        if (bp.curbitoffset <> 0) then
          flush_packed_value(bp);
        ftcb.maybe_end_aggregate(def);
        consume(_RKLAMMER);
      end;



    constructor TAsmListTypedConstBuilder.create(sym: TStaticVarSym);
      begin
        inherited;
        fsym:=sym;
        ftcb:=CTAITypedConstBuilder.create([tcalo_make_dead_strippable,tcalo_apply_constalign]);
        fdatalist:=TAsmList.create;
        curoffset:=0;
      end;


    destructor TAsmListTypedConstBuilder.Destroy;
      begin
        fdatalist.free;
        fdatalist := nil;
        ftcb.free;
        ftcb := nil;
        inherited Destroy;
      end;


    procedure TAsmListTypedConstBuilder.tc_emit_stringdef(def: TStringDef; var node: TNode);
      var
        strlength,
        defsize   : aint;
        strval    : pchar;
        ll        : TAsmLabOfs;
        winlike   : boolean;
        hsym      : TConstSym;
        paddedstrdata   : shortstring;
      begin
        strval:='';
        { load strval and strlength of the constant tree }
        if (node.nodetype=stringconstn) or is_wide_or_unicode_string(def) or is_constwidecharnode(node) or
          ((node.nodetype=typen) and Is_InterfaceCORBA(TTypeNode(node).typedef)) or
          is_constcharnode(node) then
          begin
            { convert to the expected string type so that
              for widestrings strval is a tcompilerwidestring }
            inserttypeconv(node,def);
            if (not CodeGenError) and
               (node.nodetype=stringconstn) then
              begin
                strlength:=TStringConstNode(node).len;
                if (TStringConstNode(node).cst_type in [cst_unicodestring,cst_widestring]) then
                  { further on, tstringconstnode(node).valuews is used directly for this case }
                  strval:=nil
                else
                  strval:=TStringConstNode(node).asconstpchar;
                { the def may have changed from e.g. RawByteString to
                  AnsiString(CP_ACP) }
                if node.resultdef.typ=stringdef then
                  def:=TStringDef(node.resultdef)
                else
                  InternalError(2014010501);
              end
            else
              begin
                { an error occurred trying to convert the result to a string }
                strlength:=-1;
                { it's possible that the type conversion could not be
                  evaluated at compile-time }
                if not CodeGenError then
                  CGMessage(parser_e_widestring_to_ansi_compile_time);
              end;
          end
        else if is_constresourcestringnode(node) then
          begin
            hsym:=TConstSym(TLoadNode(node).symtableentry);
            strval:=pchar(hsym.value.ValuePtr);
            strlength:=hsym.value.len;
            { Delphi-compatible (mis)feature:
              Link AnsiString constants to their initializing resourcestring,
              enabling them to be (re)translated at runtime.
              Wide/UnicodeString are currently rejected above (with incorrect error message).
              ShortStrings cannot be handled unless another table is built for them;
              considering this acceptable, because Delphi rejects them altogether.
            }
            if (not is_shortstring(def)) and
               ((tcsym.owner.SymTableLevel<=main_program_level) or
                (current_old_block_type=bt_const)) then
              begin
                CurrentAsmData.ResStrInits.Concat(
                  TTCInitItem.Create(tcsym,curoffset,
                  CurrentAsmData.RefAsmSymbol(Make_MangledName('RESSTR',hsym.owner,hsym.name),AT_DATA),CharPointerType)
                );
                Include(tcsym.VarOptions,vo_force_finalize);
              end;
          end
        else
          begin
            Message(parser_e_illegal_expression);
            strlength:=-1;
          end;
        if strlength>=0 then
          begin
            case def.StringType of
              st_shortstring:
                begin
                  ftcb.maybe_begin_aggregate(def);
                  defsize:=def.size;
                  if strlength>=defsize then
                   begin
                     message2(parser_w_string_too_long,strval,ToStr(defsize-1));
                     strlength:=defsize-1;
                   end;
                  paddedstrdata[0]:=chr(strlength);
                  move(strval^,paddedstrdata[1],strlength);
                  { fill with spaces if size is shorter }
                  fillchar(paddedstrdata[strlength+1],defsize-strlength-1,' ');
                  paddedstrdata[strlength+1]:=#0;
                  ftcb.emit_tai(TAIString.Create_Data(@paddedstrdata[0],defsize,false),CArrayDef.getreusable(CAnsiCharType,defsize+1));
                  ftcb.maybe_end_aggregate(def);
                end;
              st_ansistring:
                begin
                   { an empty ansi string is nil! }
                   if (strlength=0) then
                     begin
                       ll.lab:=nil;
                       ll.ofs:=0;
                     end
                   else
                     ll:=ftcb.emit_ansistring_const(fdatalist,strval,strlength,def.encoding);
                   ftcb.emit_string_offset(ll,strlength,def.StringType,false,CharPointerType);
                end;
              st_unicodestring,
              st_widestring:
                begin
                   { an empty wide/unicode string is nil! }
                   if (strlength=0) then
                     begin
                       ll.lab:=nil;
                       ll.ofs:=0;
                       winlike:=false;
                     end
                   else
                     begin
                       winlike:=(def.StringType=st_widestring) and (tf_winlikewidestring in TargetInfo.flags);
                       ll:=ftcb.emit_unicodestring_const(fdatalist,
                              TStringConstNode(node).ValueWS,
                              def.encoding,
                              winlike);

                       { Collect Windows widestrings that need initialization at startup.
                         Local initialized vars are excluded because they are initialized
                         at function entry instead. }
                       if winlike and
                          ((tcsym.owner.SymTableLevel<=main_program_level) or
                           (current_old_block_type=bt_const)) then
                         begin
                           if ll.ofs<>0 then
                             InternalError(2012051704);
                           CurrentAsmData.WideInits.Concat(
                              TTCInitItem.Create(tcsym,curoffset,ll.lab,WideCharPointerType)
                           );
                           ll.lab:=nil;
                           ll.ofs:=0;
                           Include(tcsym.VarOptions,vo_force_finalize);
                         end;
                     end;
                  ftcb.emit_string_offset(ll,strlength,def.StringType,winlike,WideCharPointerType);
                end;
              else
                InternalError(200107081);
            end;
          end;
      end;


    procedure TAsmListTypedConstBuilder.tc_emit_orddef(def: TOrdDef; var node: TNode);
      var
        intvalue: TConstExprInt;

      procedure do_error;
        begin
          if is_constnode(node) then
            IncompatibleTypes(node.resultdef, def)
          else if not(parse_generic) then
            Message(parser_e_illegal_expression);
        end;

      begin
        case def.OrdType of
           pasbool1,
           pasbool8,
           bool8bit,
           pasbool16,
           bool16bit,
           pasbool32,
           bool32bit,
           pasbool64,
           bool64bit:
             begin
                if is_constboolnode(node) then
                  begin
                    adaptrange(def,TOrdConstNode(node).value,false,false,cs_check_range in CurrentSettings.LocalSwitches);
                    ftcb.emit_ord_const(TOrdConstNode(node).value.svalue,def)
                  end
                else
                  do_error;
             end;
           uchar :
             begin
                if is_constwidecharnode(node) then
                  inserttypeconv(node,CAnsiCharType);
                if is_constcharnode(node) or
                  ((m_delphi in CurrentSettings.ModeSwitches) and
                   is_constwidecharnode(node) and
                   (TOrdConstNode(node).value <= 255)) then
                  ftcb.emit_ord_const(byte(TOrdConstNode(node).value.svalue),def)
                else
                  do_error;
             end;
           uwidechar :
             begin
                if is_constcharnode(node) then
                  inserttypeconv(node,CWideCharType);
                if is_constwidecharnode(node) then
                  ftcb.emit_ord_const(word(TOrdConstNode(node).value.svalue),def)
                else
                  do_error;
             end;
           s8bit,u8bit,
           u16bit,s16bit,
           s32bit,u32bit,
           s64bit,u64bit :
             begin
                if is_constintnode(node) then
                  begin
                    adaptrange(def,TOrdConstNode(node).value,false,false,cs_check_range in CurrentSettings.LocalSwitches);
                    ftcb.emit_ord_const(TOrdConstNode(node).value.svalue,def);
                  end
                else
                  do_error;
             end;
           scurrency:
             begin
                if is_constintnode(node) then
                  begin
                    if nf_is_currency in node.flags then
                      intvalue:=TOrdConstNode(node).value
                    else
                      intvalue:=TOrdConstNode(node).value*10000
                  end
                { allow bootstrapping }
                else if is_constrealnode(node) then
                  intvalue:=TRealConstNode(node).CurrencyScaledValue
                else
                  begin
                    intvalue:=0;
                    IncompatibleTypes(node.resultdef, def);
                  end;
               ftcb.emit_ord_const(intvalue,def);
             end;
           else
             InternalError(200611052);
        end;
      end;


    procedure TAsmListTypedConstBuilder.tc_emit_floatdef(def: TFloatDef; var node: TNode);
      var
        value : BestReal;
      begin
        value:=0.0;
        if is_constrealnode(node) then
          value:=TRealConstNode(node).value_real
        else if is_constintnode(node) then
          value:=TOrdConstNode(node).value
        else if is_constnode(node) then
          IncompatibleTypes(node.resultdef, def)
        else
          Message(parser_e_illegal_expression);

        case def.FloatType of
           S32Real :
             ftcb.emit_tai(TAIRealConst.create_s32real(Single(value)),def);
           S64Real :
               ftcb.emit_tai(TAIRealConst.create_s64real(Double(value)),def);
           s80real :
             ftcb.emit_tai(TAIRealConst.create_s80real(value,S80FloatType.size),def);
           sc80real :
             ftcb.emit_tai(TAIRealConst.create_s80real(value,SC80FloatType.size),def);
           s64comp :
             { the round is necessary for native compilers where comp isn't a float }
             ftcb.emit_tai(TAIRealConst.create_s64compreal(Round(value)),def);
           s64currency:
             if is_constrealnode(node) then
               ftcb.emit_tai(TAIRealConst.create_s64compreal(TRealConstNode(node).CurrencyScaledValue),def)
             else if nf_is_currency in node.flags then
               ftcb.emit_tai(TAIRealConst.create_s64compreal(Round(value)),def)
             else
               ftcb.emit_tai(TAIRealConst.create_s64compreal(Round(value*10000)),def);
        end;
      end;


    procedure TAsmListTypedConstBuilder.tc_emit_classrefdef(def: TClassRefDef; var node: TNode);
      begin
        case node.nodetype of
          loadvmtaddrn:
            begin
              if not def_is_related(TObjectDef(TClassRefDef(node.resultdef).PointedDef),TObjectDef(def.PointedDef)) then
                IncompatibleTypes(node.resultdef, def);
              ftcb.emit_tai(TAIConst.Create_sym(CurrentAsmData.RefAsmSymbol(TObjectDef(TClassRefDef(node.resultdef).PointedDef).VMT_MangledName,AT_DATA)),def);
            end;
           niln:
             ftcb.emit_tai(TAIConst.Create_sym(nil),def);
           else if is_constnode(node) then
             IncompatibleTypes(node.resultdef, def)
           else
             Message(parser_e_illegal_expression);
        end;
      end;


    procedure TAsmListTypedConstBuilder.tc_emit_pointerdef(def: TPointerDef; var node: TNode);
      var
        hp        : TNode;
        srsym     : TSym;
        pd        : TProcDef;
        pw        : TCompilerWideString;
        i,len     : LongInt;
        ll        : TAsmLabel;
        varalign  : shortint;
        datadef   : TDef;
        datatcb   : TTAITypedConstBuilder;
      begin
        { remove equal typecasts for pointer/nil addresses }
        if (node.nodetype=typeconvn) then
          with TTypeConvNode(node) do
            if (left.nodetype in [addrn,niln]) and equal_defs(def,node.resultdef) then
              begin
                hp:=left;
                left:=nil;
                node.free;
                node:=hp;
              end;
        { allows horrible ofs(typeof(TButton)^) code !! }
        if (node.nodetype=typeconvn) then
          with TTypeConvNode(node) do
            if (left.nodetype=addrn) and equal_defs(UIntType,node.resultdef) then
              begin
                hp:=left;
                left:=nil;
                node.free;
                node:=hp;
              end;
        if (node.nodetype=addrn) then
          with TAddrNode(node) do
            if left.nodetype=derefn then
              begin
                hp:=TDerefNode(left).left;
                TDerefNode(left).left:=nil;
                node.free;
                node:=hp;
             end;
        { const pointer ? }
        if (node.nodetype = pointerconstn) then
          begin
            ftcb.queue_init(def);
            ftcb.queue_typeconvn(PtrSIntType,def);
            {$ifdef cpu64bitaddr}
              ftcb.queue_emit_ordconst(int64(TPointerConstNode(node).value),PtrSIntType);
            {$else}
              {$ifdef cpu32bitaddr}
                ftcb.queue_emit_ordconst(LongInt(TPointerConstNode(node).value),PtrSIntType);
              {$else}
                InternalError(200404122);
            {$endif} {$endif}
          end
        { nil pointer ? }
        else if node.nodetype=niln then
          ftcb.emit_tai(TAIConst.Create_sym(nil),def)
        { maybe pchar ? }
        else
          if is_char(def.PointedDef) and
            ((node.nodetype=stringconstn) or is_constcharnode(node) or is_constwidecharnode(node)) then
            begin
              { ensure that a widestring is converted to the current codepage }
              if is_constwidecharnode(node) then
                begin
                  InitWideString(pw);
                  ConcatWideStringChar(pw,TCompilerWideChar(word(TOrdConstNode(node).value.svalue)));
                  hp:=CStringConstNode.createunistr(pw);
                  DoneWideString(pw);
                  node.free;
                  DoTypeCheckPass(hp);
                  node:=hp;
                end;
              if (node.nodetype=stringconstn) and is_wide_or_unicode_string(node.resultdef) then
                TStringConstNode(node).changestringtype(GetAnsiStringDef);
              { create a tcb for the string data (it's placed in a separate
                asmlist) }
              ftcb.start_internal_data_builder(fdatalist,sec_rodata_norel,'',datatcb,ll);
              if node.nodetype=stringconstn then
                varalign:=Size_2_Align(TStringConstNode(node).len)
              else
                varalign:=1;
              varalign:=Const_Align(varalign);
              { represent the string data as an array }
              if node.nodetype=stringconstn then
                begin
                  len:=TStringConstNode(node).len;
                  datadef:=CArrayDef.getreusable(CAnsiCharType,len+1);
                  datatcb.maybe_begin_aggregate(datadef);
                  if len>0 then
                    datatcb.emit_tai(TAIString.Create_Data(@TStringConstNode(node).valueas[0],len,true),datadef)
                  else
                    datatcb.emit_tai(TAIString.Create_Data(nil,0,true),datadef);
                  datatcb.maybe_end_aggregate(datadef);
                end
              else if is_constcharnode(node) then
                begin
                  datadef:=CArrayDef.getreusable(CAnsiCharType,2);
                  datatcb.maybe_begin_aggregate(datadef);
                  datatcb.emit_tai(TAIString.Create(char(byte(TOrdConstNode(node).value.svalue))+#0),datadef);
                  datatcb.maybe_end_aggregate(datadef);
                end
              else
                begin
                  Message(parser_e_illegal_expression);
                  datadef:=CArrayDef.getreusable(CAnsiCharType,1);
                end;
              ftcb.finish_internal_data_builder(datatcb,ll,datadef,varalign);
              { we now emit the address of the first element of the array
                containing the string data }
              ftcb.queue_init(def);
              { the first element ... }
              ftcb.queue_vecn(datadef,0);
              { ... of the string array }
              ftcb.queue_emit_asmsym(ll,datadef);
            end
        { maybe pwidechar ? }
        else
          if is_widechar(def.PointedDef) and
            (node.nodetype in [stringconstn,ordconstn]) then
            begin
              if (node.nodetype in [stringconstn,ordconstn]) then
                begin
                  { convert to unicodestring stringconstn }
                  inserttypeconv(node,CUnicodeStringType);
                  if (node.nodetype=stringconstn) and
                     (TStringConstNode(node).cst_type in [cst_widestring,cst_unicodestring]) then
                   begin
                     { create a tcb for the string data (it's placed in a separate
                       asmlist) }
                     ftcb.start_internal_data_builder(fdatalist,sec_rodata,'',datatcb,ll);
                     datatcb:=CTAITypedConstBuilder.create([tcalo_is_lab,tcalo_make_dead_strippable,tcalo_apply_constalign]);
                     pw:=TStringConstNode(node).ValueWS;
                     { include terminating #0 }
                     datadef:=CArrayDef.getreusable(CWideCharType,TStringConstNode(node).len+1);
                     datatcb.maybe_begin_aggregate(datadef);
                     for i:=0 to TStringConstNode(node).len-1 do
                       datatcb.emit_tai(TAIConst.Create_16bit(pw.data[i]),CWideCharType);
                     { ending #0 }
                     datatcb.emit_tai(TAIConst.Create_16bit(0),CWideCharType);
                     datatcb.maybe_end_aggregate(datadef);
                     { concat add the string data to the fdatalist }
                     ftcb.finish_internal_data_builder(datatcb,ll,datadef,Const_Align(sizeof(PInt)));
                     { we now emit the address of the first element of the array
                       containing the string data }
                     ftcb.queue_init(def);
                     { the first element ... }
                     ftcb.queue_vecn(datadef,0);
                     { ... of the string array }
                     ftcb.queue_emit_asmsym(ll,datadef);
                   end;
                end
              else
                Message(parser_e_illegal_expression);
          end
        else
          if (node.nodetype in [addrn,addn,subn]) or
             is_proc2procvar_load(node,pd) then
            begin
              { insert typeconv }
              inserttypeconv(node,def);
              hp:=node;
              while Assigned(hp) and (hp.nodetype in [addrn,typeconvn,subscriptn,vecn,addn,subn]) do
                hp:=TUnaryNode(hp).left;
              if (hp.nodetype=loadn) then
                begin
                  hp:=node;
                  ftcb.queue_init(def);
                  while Assigned(hp) and (hp.nodetype<>loadn) do
                    begin
                       case hp.nodetype of
                         addn :
                           begin
                             if (is_constintnode(TAddNode(hp).right) or
                               is_constenumnode(TAddNode(hp).right) or
                               is_constcharnode(TAddNode(hp).right) or
                               is_constboolnode(TAddNode(hp).right)) and
                               is_pointer(TAddNode(hp).left.resultdef) then
                               ftcb.queue_pointeraddn(TPointerDef(TAddNode(hp).left.resultdef),get_ordinal_value(TAddNode(hp).right))
                             else
                               Message(parser_e_illegal_expression);
                           end;
                         subn :
                           begin
                             if (is_constintnode(TAddNode(hp).right) or
                               is_constenumnode(TAddNode(hp).right) or
                               is_constcharnode(TAddNode(hp).right) or
                               is_constboolnode(TAddNode(hp).right)) and
                               is_pointer(TAddNode(hp).left.resultdef) then
                               ftcb.queue_pointersubn(TPointerDef(TAddNode(hp).left.resultdef),get_ordinal_value(TAddNode(hp).right))
                             else
                               Message(parser_e_illegal_expression);
                           end;
                         vecn :
                           begin
                             if (is_constintnode(TVecNode(hp).right) or
                                 is_constenumnode(TVecNode(hp).right) or
                                 is_constcharnode(TVecNode(hp).right) or
                                 is_constboolnode(TVecNode(hp).right)) and
                                not Is_Implicit_Array_Pointer(TVecNode(hp).left.resultdef) then
                               ftcb.queue_vecn(TVecNode(hp).left.resultdef,get_ordinal_value(TVecNode(hp).right))
                             else
                               Message(parser_e_illegal_expression);
                           end;
                         subscriptn :
                           ftcb.queue_subscriptn(TAbstractRecordDef(TSubscriptNode(hp).left.resultdef),TSubscriptNode(hp).vs);
                         typeconvn :
                           begin
                             if not(TTypeConvNode(hp).convtype in [tc_equal,tc_proc_2_procvar]) then
                               Message(parser_e_illegal_expression)
                             else
                               ftcb.queue_typeconvn(TTypeConvNode(hp).left.resultdef,hp.resultdef);
                           end;
                         addrn :
                           { nothing, is implicit };
                         else
                           Message(parser_e_illegal_expression);
                       end;
                       hp:=TUnaryNode(hp).left;
                    end;
                  srsym:=TLoadNode(hp).symtableentry;
                  case srsym.typ of
                    ProcSym :
                      begin
                        pd:=TProcDef(TProcSym(srsym).ProcdefList[0]);
                        if TProcSym(srsym).ProcdefList.Count>1 then
                          Message(parser_e_no_overloaded_procvars);
                        if po_abstractmethod in pd.ProcOptions then
                          Message(type_e_cant_take_address_of_abstract_method)
                        else
                          ftcb.queue_emit_proc(pd);
                      end;
                    staticvarsym :
                      ftcb.queue_emit_staticvar(TStaticVarSym(srsym));
                    labelsym :
                      ftcb.queue_emit_label(TLabelSym(srsym));
                    constsym :
                      if TConstSym(srsym).ConstTyp in [constresourcestring,constwresourcestring] then
                        ftcb.queue_emit_const(TConstSym(srsym))
                      else
                        Message(type_e_constant_expr_expected);
                    else
                      Message(type_e_constant_expr_expected);
                  end;
                end
              else
                Message(parser_e_illegal_expression);
            end
        else
        { allow typeof(Object type)}
          if (node.nodetype=inlinen) and
             (TInlineNode(node).inlinenumber=in_typeof_x) then
            begin
              if (TInlineNode(node).left.nodetype=typen) then
                begin
                  // TODO correct type?
                  ftcb.emit_tai(TAIConst.createname(
                    TObjectDef(TInlineNode(node).left.resultdef).VMT_MangledName,AT_DATA,0),
                    VoidPointerType);
                end
              else
                Message(parser_e_illegal_expression);
            end
        else
          Message(parser_e_illegal_expression);
      end;


    procedure TAsmListTypedConstBuilder.tc_emit_setdef(def: TSetDef; var node: TNode);
      type
         TSetBytes = array[0..31] of byte;
         PSetBytes = ^TSetBytes;
      var
        i: LongInt;
        setval: cardinal;
      begin
        if node.nodetype=setconstn then
          begin
            { be sure to convert to the correct result, else
              it can generate smallset data instead of normalset (PFV) }
            inserttypeconv(node,def);
            { we only allow const sets }
            if (node.nodetype<>setconstn) or
               Assigned(TSetConstNode(node).left) then
              Message(parser_e_illegal_expression)
            else
              begin
                ftcb.maybe_begin_aggregate(def);
                TSetConstNode(node).adjustforsetbase;
                { this writing is endian-dependant   }
                if not is_smallset(def) then
                  begin
                    if SourceInfo.endian=TargetInfo.endian then
                      begin
                        for i:=0 to node.resultdef.size-1 do
                          ftcb.emit_tai(TAIConst.create_8bit(PSetBytes(TSetConstNode(node).value_set)^[i]),U8IntType);
                      end
                    else
                      begin
                        for i:=0 to node.resultdef.size-1 do
                          ftcb.emit_tai(TAIConst.create_8bit(Reverse_Byte(PSetBytes(TSetConstNode(node).value_set)^[i])),U8IntType);
                      end;
                  end
                else
                  begin
                    { emit the set as a single constant (would be nicer if we
                      could automatically merge the bytes inside the
                      typed const builder, but it's not easy :/ ) }
                    setval:=0;
                    if SourceInfo.endian=TargetInfo.endian then
                      begin
                        for i:=0 to node.resultdef.size-1 do
                          setval:=setval or (PSetBytes(TSetConstNode(node).value_set)^[i] shl (i*8));
                      end
                    else
                      begin
                        for i:=0 to node.resultdef.size-1 do
                          setval:=setval or (Reverse_Byte(PSetBytes(TSetConstNode(node).value_set)^[i]) shl (i*8));
                      end;
                    case def.size of
                      1:
                        ftcb.emit_tai(TAIConst.create_8bit(setval),def);
                      2:
                        begin
                          if TargetInfo.endian=endian_big then
                            setval:=swapendian(word(setval));
                          ftcb.emit_tai(TAIConst.create_16bit(setval),def);
                        end;
                      4:
                        begin
                          if TargetInfo.endian=endian_big then
                            setval:=swapendian(cardinal(setval));
                          ftcb.emit_tai(TAIConst.create_32bit(LongInt(setval)),def);
                        end;
                      else
                        InternalError(2015112207);
                    end;
                  end;
                ftcb.maybe_end_aggregate(def);
              end;
          end
        else
          Message(parser_e_illegal_expression);
      end;


    procedure TAsmListTypedConstBuilder.tc_emit_enumdef(def: TEnumDef; var node: TNode);
      var
        equal: boolean;
      begin
        if node.nodetype=ordconstn then
          begin
            equal:=equal_defs(node.resultdef,def);
            if equal or
               is_subequal(node.resultdef,def) then
              begin
                { if equal, the necessary range checking has already been
                  performed; needed for handling hacks like
                    const x = tenum(255); }
                if not equal then
                  adaptrange(def,TOrdConstNode(node).value,false,false,cs_check_range in CurrentSettings.LocalSwitches);
                case node.resultdef.size of
                  1 : ftcb.emit_tai(TAIConst.Create_8bit(Byte(TOrdConstNode(node).value.svalue)),def);
                  2 : ftcb.emit_tai(TAIConst.Create_16bit(Word(TOrdConstNode(node).value.svalue)),def);
                  4 : ftcb.emit_tai(TAIConst.Create_32bit(LongInt(TOrdConstNode(node).value.svalue)),def);
                  else
                    InternalError(2022040301);
                end;
              end
            else
              IncompatibleTypes(node.resultdef,def);
          end
        else
          Message(parser_e_illegal_expression);
      end;


    { parse a single constant and add it to the packed const info  }
    { represented by curval etc (see explanation of bitpackval for }
    { what the different parameters mean)                          }
    function TAsmListTypedConstBuilder.parse_single_packed_const(def: TDef; var bp: TBitPackedVal): boolean;
      var
        node: TNode;
      begin
        result:=true;
        node:=comp_expr([ef_accept_equal]);
        if (node.nodetype <> ordconstn) or
           (not equal_defs(node.resultdef,def) and
            not is_subequal(node.resultdef,def)) then
          begin
            IncompatibleTypes(node.resultdef,def);
            node.free;
            node := nil;
            consume_all_until(_SEMICOLON);
            result:=false;
            exit;
          end;
        if (TOrdConstNode(node).value<qword(low(Aword))) or (TOrdConstNode(node).value>qword(high(Aword))) then
          message3(type_e_range_check_error_bounds,ToStr(TOrdConstNode(node).value),ToStr(low(Aword)),ToStr(high(Aword)))
        else
          bitpackval(TOrdConstNode(node).value.uvalue,bp);
        if (bp.curbitoffset>=AIntBits) then
          flush_packed_value(bp);
        node.free;
        node := nil;
      end;

    procedure TAsmListTypedConstBuilder.get_final_asmlists(out reslist, datalist: TAsmList);
      var
        asmsym: TAsmSymbol;
        sec: TAsmSectiontype;
        secname: AnsiString;
      begin
        if fsym.GlobalAsmSym then
          begin
            asmsym:=CurrentAsmData.DefineAsmSymbol(fsym.MangledName,AB_GLOBAL,AT_DATA,tcsym.vardef)
          end
        else if tf_supports_hidden_symbols in TargetInfo.flags then
          asmsym:=CurrentAsmData.DefineAsmSymbol(fsym.MangledName,AB_PRIVATE_EXTERN,AT_DATA,tcsym.vardef)
        else
          asmsym:=CurrentAsmData.DefineAsmSymbol(fsym.MangledName,AB_LOCAL,AT_DATA,tcsym.vardef);
        if vo_has_section in fsym.VarOptions then
          begin
            sec:=sec_user;
            secname:=fsym.section;
          end
        else
          begin
            { Certain types like windows WideString are initialized at runtime and cannot
              be placed into readonly memory }
            if (fsym.VarSpez=vs_const) and
               not (vo_force_finalize in fsym.VarOptions) then
              sec:=sec_rodata
            else
              sec:=sec_data;
            secname:=asmsym.Name;
          end;
        reslist:=ftcb.get_final_asmlist(asmsym,fsym,fsym.vardef,sec,secname,fsym.vardef.alignment);
        datalist:=fdatalist;
      end;


    procedure TAsmListTypedConstBuilder.parse_arraydef(def:TArrayDef);
      const
        LKlammerToken: array[Boolean] of TToken = (_LKLAMMER, _LECKKLAMMER);
        RKlammerToken: array[Boolean] of TToken = (_RKLAMMER, _RECKKLAMMER);
      var
        n : TNode;
        i : LongInt;
        len : asizeint;
        ch  : array[0..1] of char;
        ca  : PByte;
        int_const: TAIConst;
        char_size: integer;
        dyncount,
        oldoffset: asizeint;
        dummy : byte;
        sectype : TAsmSectiontype;
        oldtcb,
        datatcb : TTAITypedConstBuilder;
        ll : TAsmLabel;
        dyncountloc : TTypedConstPlaceholder;
        llofs : TAsmLabOfs;
        dynarrdef : TDef;
      begin
        { dynamic array }
        if is_dynamic_array(def) then
          begin
            if try_to_consume(_NIL) then
              begin
                ftcb.emit_tai(TAIConst.Create_sym(nil),def);
              end
            else if try_to_consume(LKlammerToken[m_delphi in CurrentSettings.ModeSwitches]) then
              begin
                if try_to_consume(RKlammerToken[m_delphi in CurrentSettings.ModeSwitches]) then
                  begin
                    ftcb.emit_tai(TAIConst.create_sym(nil),def);
                  end
                else
                  begin
                    if fsym.VarSpez=vs_const then
                      sectype:=sec_rodata
                    else
                      sectype:=sec_data;
                    ftcb.start_internal_data_builder(fdatalist,sectype,'',datatcb,ll);

                    llofs:=datatcb.begin_dynarray_const(def,ll,dyncountloc);

                    dyncount:=0;

                    oldtcb:=ftcb;
                    ftcb:=datatcb;
                    while true do
                      begin
                        read_typed_const_data(def.ElementDef);
                        inc(dyncount);
                        if try_to_consume(RKlammerToken[m_delphi in CurrentSettings.ModeSwitches]) then
                          break
                        else
                          consume(_COMMA);
                      end;
                    ftcb:=oldtcb;

                    dynarrdef:=datatcb.end_dynarray_const(def,dyncount,dyncountloc,llofs);

                    ftcb.finish_internal_data_builder(datatcb,ll,dynarrdef,sizeof(PInt));

                    ftcb.emit_dynarray_offset(llofs,dyncount,def,TRecordDef(dynarrdef));
                  end;
              end
            else
              consume(_LKLAMMER);
          end
        { packed array constant }
        else if is_packed_array(def) and
                (def.ElementDef.typ in [orddef,enumdef]) and
                ((def.ElePackedBitSize mod 8 <> 0) or
                 not IsPowerOf2(def.ElePackedBitSize div 8,i)) then
          begin
            parse_packed_array_def(def);
          end
        { normal array const between brackets }
        else if try_to_consume(_LKLAMMER) then
          begin
            ftcb.maybe_begin_aggregate(def);
            oldoffset:=curoffset;
            curoffset:=0;
            { in case of a generic subroutine, it might be we cannot
              determine the size yet }
            if Assigned(CurrentProcInfo) and (df_generic in CurrentProcInfo.procdef.DefOptions) then
              begin
                while true do
                  begin
                    read_typed_const_data(def.ElementDef);
                    if CurrentScanner.token=_RKLAMMER then
                      begin
                        consume(_RKLAMMER);
                        break;
                      end
                    else
                      consume(_COMMA);
                  end;
              end
            else
              begin
                for i:=def.LowRange to def.HighRange-1 do
                  begin
                    read_typed_const_data(def.ElementDef);
                    Inc(curoffset,def.ElementDef.size);
                    if CurrentScanner.token=_RKLAMMER then
                      begin
                        Message1(parser_e_more_array_elements_expected,ToStr(def.HighRange-i));
                        consume(_RKLAMMER);
                        exit;
                      end
                    else
                      consume(_COMMA);
                  end;
                read_typed_const_data(def.ElementDef);
                consume(_RKLAMMER);
              end;
            curoffset:=oldoffset;
            if ErrorCount=0 then
              ftcb.maybe_end_aggregate(def);
          end
        { if array of char then we allow also a string }
        else if is_anychar(def.ElementDef) then
          begin
             ftcb.maybe_begin_aggregate(def);
             char_size:=def.ElementDef.size;
             n:=comp_expr([ef_accept_equal]);
             if n.nodetype=stringconstn then
               begin
                 len:=TStringConstNode(n).len;
                  case char_size of
                    1:
                     begin
                       if (TStringConstNode(n).cst_type in [cst_unicodestring,cst_widestring]) then
                         inserttypeconv(n,GetAnsiStringDef);
                       if n.nodetype<>stringconstn then
                         InternalError(2010033003);
                       ca:=pointer(TStringConstNode(n).valueas);
                     end;
                    2:
                      begin
                        inserttypeconv(n,CUnicodeStringType);
                        if n.nodetype<>stringconstn then
                          InternalError(2010033009);
                        if TStringConstNode(n).ValueWS.len>0 then
                          ca:=pointer(@TStringConstNode(n).ValueWS.data[0])
                        else
                          ca:=nil;
                      end;
                    else
                      InternalError(2010033005);
                  end;
               end
             else if is_constcharnode(n) then
                begin
                  case char_size of
                    1:
                      ch[0]:=chr(TOrdConstNode(n).value.uvalue and $ff);
                    2:
                      begin
                        inserttypeconv(n,CWideCharType);
                        if not is_constwidecharnode(n) then
                          InternalError(2010033001);
                        widechar(ch):=widechar(TOrdConstNode(n).value.uvalue and $ffff);
                      end;
                    else
                      InternalError(2010033002);
                  end;
                  ca:=@ch;
                  len:=1;
                end
             else if is_constwidecharnode(n) and (CurrentSettings.SourceCodePage<>CP_UTF8) then
                begin
                  case char_size of
                    1:
                      begin
                        inserttypeconv(n,CAnsiCharType);
                        if not is_constcharnode(n) then
                          InternalError(2010033006);
                        ch[0]:=chr(TOrdConstNode(n).value.uvalue and $ff);
                      end;
                    2:
                      widechar(ch):=widechar(TOrdConstNode(n).value.uvalue and $ffff);
                    else
                      InternalError(2010033008);
                  end;
                  ca:=@ch;
                  len:=1;
                end
             else
               begin
                 Message(parser_e_illegal_expression);
                 len:=0;
                 { avoid crash later on }
                 dummy:=0;
                 ca:=@dummy;
               end;
             if len>(def.HighRange-def.LowRange+1) then
               Message(parser_e_string_larger_array);
             for i:=0 to def.HighRange-def.LowRange do
               begin
                 if i<len then
                   begin
                     case char_size of
                       1:
                        int_const:=TAIConst.Create_char(char_size,PByte(ca)^);
                       2:
                        int_const:=TAIConst.Create_char(char_size,PWord(ca)^);
                       else
                         InternalError(2010033004);
                     end;
                     inc(ca, char_size);
                   end
                 else
                   {Fill the remaining positions with #0.}
                   int_const:=TAIConst.Create_char(char_size,0);
                 ftcb.emit_tai(int_const,def.ElementDef)
               end;
             ftcb.maybe_end_aggregate(def);
             n.free;
             n := nil;
          end
        else
          begin
            { we want the ( }
            consume(_LKLAMMER);
          end;
      end;


    procedure TAsmListTypedConstBuilder.parse_procvardef(def:TProcVarDef);
      var
        tmpn,n : TNode;
        pd : TProcDef;
        procaddrdef: TProcVarDef;
        havepd,
        haveblock: boolean;
        selfnode: TNode;
        selfdef: TDef;
      begin
        { Procvars and pointers are no longer compatible.  }
        { under tp:  =nil or =var under fpc: =nil or =@var }
        if try_to_consume(_NIL) then
          begin
             ftcb.maybe_begin_aggregate(def);
             { we need the procdef type called by the procvar here, not the
               procvar record }
             ftcb.emit_tai_procvar2procdef(TAIConst.Create_sym(nil),def);
             if not def.Is_AddressOnly then
               ftcb.emit_tai(TAIConst.Create_sym(nil),VoidPointerType);
             ftcb.maybe_end_aggregate(def);
             exit;
          end;
        { parse the rest too, so we can continue with error checking }
        getprocvardef:=def;
        n:=comp_expr([ef_accept_equal]);
        getprocvardef:=nil;
        if CodeGenError then
          begin
            n.free;
            n := nil;
            exit;
          end;
        { let type conversion check everything needed }
        inserttypeconv(n,def);
        if CodeGenError then
          begin
            n.free;
            n := nil;
            exit;
          end;
        { in case of a nested procdef initialised with a global routine }
        ftcb.maybe_begin_aggregate(def);
        { get the address of the procedure, except if it's a C-block (then we
          we will end up with a record that represents the C-block) }
        if not is_block(def) then
          procaddrdef:=CProcVarDef.GetReusableProcAddr(def,pc_address_only)
        else
          procaddrdef:=def;
        ftcb.queue_init(procaddrdef);
        { remove typeconvs, that will normally insert a lea
          instruction which is not necessary for us }
        while n.nodetype=typeconvn do
          begin
            ftcb.queue_typeconvn(TTypeConvNode(n).left.resultdef,n.resultdef);
            tmpn:=TTypeConvNode(n).left;
            TTypeConvNode(n).left:=nil;
            n.free;
            n:=tmpn;
          end;
        { remove addrn which we also don't need here }
        if n.nodetype=addrn then
          begin
            tmpn:=TAddrNode(n).left;
            TAddrNode(n).left:=nil;
            n.free;
            n:=tmpn;
          end;
        pd:=nil;
        { we now need to have a loadn with a procsym }
        havepd:=
          (n.nodetype=loadn) and
          (TLoadNode(n).symtableentry.typ=ProcSym);
        { or a staticvarsym representing a block }
        haveblock:=
          (n.nodetype=loadn) and
          (TLoadNode(n).symtableentry.typ=staticvarsym) and
          (sp_internal in TLoadNode(n).symtableentry.SymOptions);
        if havepd or
           haveblock then
          begin
            if havepd then
              begin
                pd:=TLoadNode(n).procdef;
                ftcb.queue_emit_proc(pd);
              end
            else
              begin
                ftcb.queue_emit_staticvar(TStaticVarSym(TLoadNode(n).symtableentry));
              end;
            { the Data field of a method pointer can be initialised
              either with NIL (handled above) or with a class type }
            if po_methodpointer in def.ProcOptions then
              begin
                selfnode:=TLoadNode(n).left;
                { class type must be known at compile time }
                if Assigned(selfnode) and
                    (selfnode.nodetype=loadvmtaddrn) and
                    (TLoadVMTAddrNode(selfnode).left.nodetype=typen) then
                  begin
                    selfdef:=selfnode.resultdef;
                    if selfdef.typ<>classrefdef then
                      InternalError(2021122301);
                    selfdef:=TClassRefDef(selfdef).PointedDef;
                    ftcb.emit_tai(TAIConst.Create_sym(
                      CurrentAsmData.RefAsmSymbol(TObjectDef(selfdef).VMT_MangledName,AT_DATA)),
                      VoidPointerType);
                  end
                else
                  Message(parser_e_no_procvarobj_const);
              end
            { nested procvar typed consts can only be initialised with nil
              (checked above) or with a global procedure (checked here),
              because in other cases we need a valid frame pointer }
            else if is_nested_pd(def) then
              begin
                if haveblock or
                   is_nested_pd(pd) then
                  Message(parser_e_no_procvarnested_const);
                ftcb.emit_tai(TAIConst.Create_sym(nil),VoidPointerType);
              end;
          end
        else if n.nodetype=pointerconstn then
          begin
            ftcb.queue_emit_ordconst(TPointerConstNode(n).value,procaddrdef);
            if not def.Is_AddressOnly then
              ftcb.emit_tai(TAIConst.Create_sym(nil),VoidPointerType);
          end
        else if n.nodetype=niln then
          begin
            ftcb.queue_emit_ordconst(0,procaddrdef);
            if not def.Is_AddressOnly then
              ftcb.emit_tai(TAIConst.Create_sym(nil),VoidPointerType);
          end
        else
          Message(parser_e_illegal_expression);
        ftcb.maybe_end_aggregate(def);
        n.free;
        n := nil;
      end;


    procedure TAsmListTypedConstBuilder.parse_recorddef(def:TRecordDef);
      var
        n       : TNode;
        symidx  : LongInt;
        recsym,
        srsym   : TSym;
        hs      : string;
        sorg,s  : TIDString;
        tmpguid : TGUID;
        recoffset,
        fillbytes  : aint;
        bp   : TBitPackedVal;
        error,
        Is_Packed: boolean;
        startoffset: aword;

      procedure handle_stringconstn;
        begin
          if length(TStringConstNode(n).valueas)>0 then
            hs:=StrPas(@TStringConstNode(n).valueas[0])
          else
            hs:='';
          if String2GUID(hs,tmpguid) then
            ftcb.emit_guid_const(tmpguid)
          else
            Message(parser_e_improper_guid_syntax);
        end;

      var
        i : LongInt;
        SymList:TFPHashObjectList;
      begin
        { GUID }
        if (def=Rec_TGUID) and (CurrentScanner.token=_ID) then
          begin
            n:=comp_expr([ef_accept_equal]);
            if n.nodetype=stringconstn then
              handle_stringconstn
            else
              begin
                inserttypeconv(n,Rec_TGUID);
                if n.nodetype=guidconstn then
                  ftcb.emit_guid_const(TGUIDConstNode(n).value)
                else
                  Message(parser_e_illegal_expression);
              end;
            n.free;
            n := nil;
            exit;
          end;
        if (def=Rec_TGUID) and ((CurrentScanner.token=_CSTRING) or (CurrentScanner.token=_CCHAR)) then
          begin
            n:=comp_expr([ef_accept_equal]);
            inserttypeconv(n,CShortStringType);
            if n.nodetype=stringconstn then
              handle_stringconstn
            else
              Message(parser_e_illegal_expression);
            n.free;
            n := nil;
            exit;
          end;
        ftcb.maybe_begin_aggregate(def);
        { bitpacked record? }
        Is_Packed:=is_packed_record_or_object(def);
        if (Is_Packed) then
          { packedbitsize will be set separately for each field }
          initbitpackval(bp,0);
        { normal record }
        consume(_LKLAMMER);
        recoffset:=0;
        sorg:='';
        symidx:=0;
        SymList:=def.SymTable.SymList;
        srsym:=get_next_varsym(def,SymList,symidx);
        recsym := nil;
        startoffset:=curoffset;
        error := false;
        while CurrentScanner.token<>_RKLAMMER do
          begin
            s:=CurrentScanner.pattern;
            sorg:=CurrentScanner.orgpattern;
            consume(_ID);
            consume(_COLON);
            recsym := TSym(def.SymTable.Find(s));
            if not Assigned(recsym) or (recsym.typ<>FieldVarSym) then
              begin
                Message1(sym_e_illegal_field,sorg);
                error := true;
              end;
            if (not error) and
               (not Assigned(srsym) or
                (s <> srsym.name)) then
              { possible variant record (JM) }
              begin
                { All parts of a variant start at the same offset      }
                { Also allow jumping from one variant part to another, }
                { as long as the offsets match                         }
                if (Assigned(srsym) and
                    (TFieldVarSym(recsym).FieldOffset = TFieldVarSym(srsym).FieldOffset)) or
                   { srsym is not assigned after parsing w2 in the      }
                   { typed const in the next example:                   }
                   {   type tr = record case byte of                    }
                   {          1: (l1,l2: dword);                        }
                   {          2: (w1,w2: word);                         }
                   {        end;                                        }
                   {   const r: tr = (w1:1;w2:1;l2:5);                  }
                   (TFieldVarSym(recsym).FieldOffset = recoffset) then
                  begin
                    srsym:=recsym;
                    { symidx should contain the next symbol id to search }
                    symidx:=SymList.indexof(srsym)+1;
                  end
                { going backwards isn't allowed in any mode }
                else if (TFieldVarSym(recsym).FieldOffset<recoffset) then
                  begin
                    Message(parser_e_invalid_record_const);
                    error := true;
                  end
                { Delphi allows you to skip fields }
                else if (m_delphi in CurrentSettings.ModeSwitches) then
                  begin
                    Message1(parser_w_skipped_fields_before,sorg);
                    srsym := recsym;
                  end
                { FPC and TP don't }
                else
                  begin
                    Message1(parser_e_skipped_fields_before,sorg);
                    error := true;
                  end;
              end;
            if error then
              consume_all_until(_SEMICOLON)
            else
              begin
                { if needed fill (alignment) }
                if TFieldVarSym(srsym).FieldOffset>recoffset then
                  begin
                    if not(Is_Packed) then
                      fillbytes:=0
                    else
                      begin
                        flush_packed_value(bp);
                        { curoffset is now aligned to the next byte }
                        recoffset:=align(recoffset,8);
                        { offsets are in bits in this case }
                        fillbytes:=(TFieldVarSym(srsym).FieldOffset-recoffset) div 8;
                      end;
                    for i:=1 to fillbytes do
                      ftcb.emit_tai(TAIConst.Create_8bit(0),U8IntType)
                  end;

                { new position }
                recoffset:=TFieldVarSym(srsym).FieldOffset;
                if not(Is_Packed) then
                  inc(recoffset,TFieldVarSym(srsym).vardef.size)
                 else
                   inc(recoffset,TFieldVarSym(srsym).vardef.PackedBitSize);

                { read the data }
                ftcb.next_field:=TFieldVarSym(srsym);
                if not(Is_Packed) or
                   { only orddefs and enumdefs are bitpacked, as in gcc/gpc }
                   not(TFieldVarSym(srsym).vardef.typ in [orddef,enumdef]) then
                  begin
                    if Is_Packed then
                      begin
                        flush_packed_value(bp);
                        recoffset:=align(recoffset,8);
                      end;
                    curoffset:=startoffset+TFieldVarSym(srsym).FieldOffset;
                    read_typed_const_data(TFieldVarSym(srsym).vardef);
                  end
                else
                  begin
                    bp.PackedBitSize:=TFieldVarSym(srsym).vardef.PackedBitSize;
                    parse_single_packed_const(TFieldVarSym(srsym).vardef,bp);
                  end;

                { keep previous field for checking whether whole }
                { record was initialized (JM)                    }
                recsym := srsym;
                { goto next field }
                srsym:=get_next_varsym(def,SymList,symidx);

                if CurrentScanner.token=_SEMICOLON then
                  consume(_SEMICOLON)
                else if (CurrentScanner.token=_COMMA) and (m_mac in CurrentSettings.ModeSwitches) then
                  consume(_COMMA)
                else
                  break;
              end;
          end;
        curoffset:=startoffset;

        { are there any fields left, but don't complain if there only
          come other variant parts after the last initialized field }
        if Assigned(srsym) and
           (
            (recsym=nil) or
            (TFieldVarSym(srsym).FieldOffset > TFieldVarSym(recsym).FieldOffset)
           ) then
          Message1(parser_w_skipped_fields_after,sorg);

        if ErrorCount=0 then
          begin
            if not(Is_Packed) then
              fillbytes:=0
            else
              begin
                flush_packed_value(bp);
                recoffset:=align(recoffset,8);
                fillbytes:=def.size-(recoffset div 8);
              end;
            for i:=1 to fillbytes do
              ftcb.emit_tai(TAIConst.Create_8bit(0),U8IntType);

            ftcb.maybe_end_aggregate(def);
          end;

        consume(_RKLAMMER);
      end;


    procedure TAsmListTypedConstBuilder.parse_objectdef(def:TObjectDef);
      var
        n      : TNode;
        obj    : TObjectDef;
        srsym  : TSym;
        st     : TSymTable;
        objoffset : aint;
        s,sorg : TIDString;
        vmtwritten : boolean;
        startoffset : aint;
      begin
        { no support for packed object }
        if is_packed_record_or_object(def) then
          begin
            Message(type_e_no_const_packed_record);
            exit;
          end;

        { only allow nil for implicit pointer object types }
        if Is_Implicit_Pointer_Object_Type(def) then
          begin
            n:=comp_expr([ef_accept_equal]);
            if n.nodetype<>niln then
              begin
                Message(parser_e_type_const_not_possible);
                consume_all_until(_SEMICOLON);
              end
            else
              ftcb.emit_tai(TAIConst.Create_sym(nil),def);
            n.free;
            n := nil;
            exit;
          end;

        { for objects we allow it only if it doesn't contain a vmt }
        if (oo_has_vmt in def.ObjectOptions) and
           (m_fpc in CurrentSettings.ModeSwitches) then
          begin
            Message(parser_e_type_object_constants);
            exit;
          end;

        ftcb.maybe_begin_aggregate(def);

        consume(_LKLAMMER);
        startoffset:=curoffset;
        objoffset:=0;
        vmtwritten:=false;
        while CurrentScanner.token<>_RKLAMMER do
          begin
            s:=CurrentScanner.pattern;
            sorg:=CurrentScanner.orgpattern;
            consume(_ID);
            consume(_COLON);
            srsym:=nil;
            obj:=TObjectDef(def);
            st:=obj.SymTable;
            while (srsym=nil) and Assigned(st) do
              begin
                srsym:=TSym(st.Find(s));
                if Assigned(obj) then
                  obj:=obj.ChildOf;
                if Assigned(obj) then
                  st:=obj.SymTable
                else
                  st:=nil;
              end;

            if (srsym=nil) or
               (srsym.typ<>FieldVarSym) then
              begin
                if (srsym=nil) then
                  Message1(sym_e_id_not_found,sorg)
                else
                  Message1(sym_e_illegal_field,sorg);
                consume_all_until(_RKLAMMER);
                break;
              end
            else
              with TFieldVarSym(srsym) do
                begin
                  { check position }
                  if FieldOffset<objoffset then
                    message(parser_e_invalid_record_const);

                  { check in VMT needs to be added for TP mode }
                  if not(vmtwritten) and
                     not(m_fpc in CurrentSettings.ModeSwitches) and
                     (oo_has_vmt in def.ObjectOptions) and
                     (def.VMT_Offset<FieldOffset) then
                    begin
                      ftcb.next_field:=TFieldVarSym(def.VMTField);
                      ftcb.emit_tai(TAIConst.createname(def.VMT_MangledName,AT_DATA,0),TFieldVarSym(def.VMTField).vardef);
                      objoffset:=def.VMT_Offset+TFieldVarSym(def.VMTField).vardef.size;
                      vmtwritten:=true;
                    end;

                  ftcb.next_field:=TFieldVarSym(srsym);

                  { new position }
                  objoffset:=FieldOffset+vardef.size;

                  { read the data }
                  curoffset:=startoffset+FieldOffset;
                  read_typed_const_data(vardef);

                  if not try_to_consume(_SEMICOLON) then
                    break;
                end;
          end;
        curoffset:=startoffset;
        { add VMT pointer if we stopped writing fields before the VMT was
          written }
        if not(m_fpc in CurrentSettings.ModeSwitches) and
           (oo_has_vmt in def.ObjectOptions) and
           (def.VMT_Offset>=objoffset) then
          begin
            ftcb.next_field:=TFieldVarSym(def.VMTField);
            ftcb.emit_tai(TAIConst.createname(def.VMT_MangledName,AT_DATA,0),TFieldVarSym(def.VMTField).vardef);
            objoffset:=def.VMT_Offset+TFieldVarSym(def.VMTField).vardef.size;
          end;
        ftcb.maybe_end_aggregate(def);
        consume(_RKLAMMER);
      end;


    procedure TAsmListTypedConstBuilder.parse_into_asmlist;
      begin
        read_typed_const_data(tcsym.vardef);
      end;


    { tnodetreetypedconstbuilder }

    procedure TNodeTreeTypedConstBuilder.parse_arraydef(def: TArrayDef);
      var
        n : TNode;
        i : LongInt;
        orgbase: TNode;
      begin
        { dynamic array nil }
        if is_dynamic_array(def) then
          begin
            { Only allow nil initialization }
            consume(_NIL);
            addstatement(statmnt,CAssignmentNode.Create_Internal(basenode,CNilNode.create));
            basenode:=nil;
          end
        { array const between brackets }
        else if try_to_consume(_LKLAMMER) then
          begin
            orgbase:=basenode;
            for i:=def.LowRange to def.HighRange-1 do
              begin
                basenode:=CVecNode.create(orgbase.GetCopy,CTypeConvNode.create_explicit(genintconstnode(i),TArrayDef(def).RangeDef));
                read_typed_const_data(def.ElementDef);
                if CurrentScanner.token=_RKLAMMER then
                  begin
                    Message1(parser_e_more_array_elements_expected,ToStr(def.HighRange-i));
                    consume(_RKLAMMER);
                    exit;
                  end
                else
                  consume(_COMMA);
              end;
            basenode:=CVecNode.create(orgbase,CTypeConvNode.create_explicit(genintconstnode(def.HighRange),TArrayDef(def).RangeDef));
            read_typed_const_data(def.ElementDef);
            consume(_RKLAMMER);
          end
        { if array of char then we allow also a string }
        else if is_anychar(def.ElementDef) then
          begin
             n:=comp_expr([ef_accept_equal]);
             addstatement(statmnt,CAssignmentNode.Create_Internal(basenode,n));
             basenode:=nil;
          end
        else
          begin
            { we want the ( }
            consume(_LKLAMMER);
          end;
      end;


    procedure TNodeTreeTypedConstBuilder.parse_procvardef(def: TProcVarDef);
      begin
        addstatement(statmnt,CAssignmentNode.Create_Internal(basenode,comp_expr([ef_accept_equal])));
        basenode:=nil;
      end;


    procedure TNodeTreeTypedConstBuilder.parse_recorddef(def: TRecordDef);
      var
        n,n2    : TNode;
        SymList:TFPHashObjectList;
        orgbasenode : TNode;
        symidx  : LongInt;
        recsym,
        srsym   : TSym;
        sorg,s  : TIDString;
        recoffset : aint;
        error,
        Is_Packed: boolean;

      procedure handle_stringconstn;
        begin
          addstatement(statmnt,CAssignmentNode.Create_Internal(basenode,n));
          basenode:=nil;
          n:=nil;
        end;

      begin
        { GUID }
        if (def=Rec_TGUID) and (CurrentScanner.token=_ID) then
          begin
            n:=comp_expr([ef_accept_equal]);
            if n.nodetype=stringconstn then
              handle_stringconstn
            else
              begin
                inserttypeconv(n,Rec_TGUID);
                if n.nodetype=guidconstn then
                  begin
                    n2:=CStringConstNode.createstr(GUID2String(TGUIDConstNode(n).value));
                    n.free;
                    n:=n2;
                    handle_stringconstn;
                  end
                else
                  Message(parser_e_illegal_expression);
              end;
            n.free;
            n := nil;
            exit;
          end;
        if (def=Rec_TGUID) and ((CurrentScanner.token=_CSTRING) or (CurrentScanner.token=_CCHAR)) then
          begin
            n:=comp_expr([ef_accept_equal]);
            inserttypeconv(n,CShortStringType);
            if n.nodetype=stringconstn then
              handle_stringconstn
            else
              Message(parser_e_illegal_expression);
            n.free;
            n := nil;
            exit;
          end;
        { bitpacked record? }
        Is_Packed:=is_packed_record_or_object(def);
        { normal record }
        consume(_LKLAMMER);
        recoffset:=0;
        sorg:='';
        symidx:=0;
        SymList:=def.SymTable.SymList;
        srsym:=get_next_varsym(def,SymList,symidx);
        recsym := nil;
        orgbasenode:=basenode;
        basenode:=nil;
        while CurrentScanner.token<>_RKLAMMER do
          begin
            s:=CurrentScanner.pattern;
            sorg:=CurrentScanner.orgpattern;
            consume(_ID);
            consume(_COLON);
            error := false;
            recsym := TSym(def.SymTable.Find(s));
            if not Assigned(recsym) then
              begin
                Message1(sym_e_illegal_field,sorg);
                error := true;
              end;
            if (not error) and
               (not Assigned(srsym) or
                (s <> srsym.name)) then
              { possible variant record (JM) }
              begin
                { All parts of a variant start at the same offset      }
                { Also allow jumping from one variant part to another, }
                { as long as the offsets match                         }
                if (Assigned(srsym) and
                    (TFieldVarSym(recsym).FieldOffset = TFieldVarSym(srsym).FieldOffset)) or
                   { srsym is not assigned after parsing w2 in the      }
                   { typed const in the next example:                   }
                   {   type tr = record case byte of                    }
                   {          1: (l1,l2: dword);                        }
                   {          2: (w1,w2: word);                         }
                   {        end;                                        }
                   {   const r: tr = (w1:1;w2:1;l2:5);                  }
                   (TFieldVarSym(recsym).FieldOffset = recoffset) then
                  begin
                    srsym:=recsym;
                    { symidx should contain the next symbol id to search }
                    symidx:=SymList.indexof(srsym)+1;
                  end
                { going backwards isn't allowed in any mode }
                else if (TFieldVarSym(recsym).FieldOffset<recoffset) then
                  begin
                    Message(parser_e_invalid_record_const);
                    error := true;
                  end
                { Delphi allows you to skip fields }
                else if (m_delphi in CurrentSettings.ModeSwitches) then
                  begin
                    Message1(parser_w_skipped_fields_before,sorg);
                    srsym := recsym;
                  end
                { FPC and TP don't }
                else
                  begin
                    Message1(parser_e_skipped_fields_before,sorg);
                    error := true;
                  end;
              end;
            if error then
              consume_all_until(_SEMICOLON)
            else
              begin
                { skipping fill bytes happens automatically, since we only
                  initialize the defined fields }
                { new position }
                recoffset:=TFieldVarSym(srsym).FieldOffset;
                if not(Is_Packed) then
                  inc(recoffset,TFieldVarSym(srsym).vardef.size)
                 else
                   inc(recoffset,TFieldVarSym(srsym).vardef.PackedBitSize);

                { read the data }
                if Is_Packed and
                   { only orddefs and enumdefs are bitpacked, as in gcc/gpc }
                   not(TFieldVarSym(srsym).vardef.typ in [orddef,enumdef]) then
                  recoffset:=align(recoffset,8);
                basenode:=CSubscriptNode.create(srsym,orgbasenode.GetCopy);
                read_typed_const_data(TFieldVarSym(srsym).vardef);

                { keep previous field for checking whether whole }
                { record was initialized (JM)                    }
                recsym := srsym;
                { goto next field }
                srsym:=get_next_varsym(def,SymList,symidx);
                if CurrentScanner.token=_SEMICOLON then
                  consume(_SEMICOLON)
                else if (CurrentScanner.token=_COMMA) and (m_mac in CurrentSettings.ModeSwitches) then
                  consume(_COMMA)
                else
                  break;
              end;
          end;

        { are there any fields left, but don't complain if there only
          come other variant parts after the last initialized field }
        if Assigned(srsym) and
           (
            (recsym=nil) or
            (TFieldVarSym(srsym).FieldOffset > TFieldVarSym(recsym).FieldOffset)
           ) then
          Message1(parser_w_skipped_fields_after,sorg);
        orgbasenode.free;
        orgbasenode := nil;
        basenode:=nil;

        consume(_RKLAMMER);
      end;


    procedure TNodeTreeTypedConstBuilder.parse_objectdef(def: TObjectDef);
      var
        n,
        orgbasenode : TNode;
        obj    : TObjectDef;
        srsym  : TSym;
        st     : TSymTable;
        objoffset : aint;
        s,sorg : TIDString;
      begin
        { no support for packed object }
        if is_packed_record_or_object(def) then
          begin
            Message(type_e_no_const_packed_record);
            exit;
          end;

        { only allow nil for implicit pointer object types }
        if Is_Implicit_Pointer_Object_Type(def) then
          begin
            n:=comp_expr([ef_accept_equal]);
            if n.nodetype<>niln then
              begin
                Message(parser_e_type_const_not_possible);
                consume_all_until(_SEMICOLON);
              end
            else
              begin
                addstatement(statmnt,CAssignmentNode.Create_Internal(basenode,n));
                n:=nil;
                basenode:=nil;
              end;
            n.free;
            n := nil;
            exit;
          end;

        { for objects we allow it only if it doesn't contain a vmt }
        if (oo_has_vmt in def.ObjectOptions) and
           (m_fpc in CurrentSettings.ModeSwitches) then
          begin
            Message(parser_e_type_object_constants);
            exit;
          end;

        consume(_LKLAMMER);
        objoffset:=0;
        orgbasenode:=basenode;
        basenode:=nil;
        while CurrentScanner.token<>_RKLAMMER do
          begin
            s:=CurrentScanner.pattern;
            sorg:=CurrentScanner.orgpattern;
            consume(_ID);
            consume(_COLON);
            srsym:=nil;
            obj:=TObjectDef(def);
            st:=obj.SymTable;
            while (srsym=nil) and Assigned(st) do
              begin
                srsym:=TSym(st.Find(s));
                if Assigned(obj) then
                  obj:=obj.ChildOf;
                if Assigned(obj) then
                  st:=obj.SymTable
                else
                  st:=nil;
              end;

            if (srsym=nil) or
               (srsym.typ<>FieldVarSym) then
              begin
                if (srsym=nil) then
                  Message1(sym_e_id_not_found,sorg)
                else
                  Message1(sym_e_illegal_field,sorg);
                consume_all_until(_RKLAMMER);
                break;
              end
            else
              with TFieldVarSym(srsym) do
                begin
                  { check position }
                  if FieldOffset<objoffset then
                    message(parser_e_invalid_record_const);

                  { new position }
                  objoffset:=FieldOffset+vardef.size;

                  { read the data }
                  basenode:=CSubscriptNode.create(srsym,orgbasenode.GetCopy);
                  read_typed_const_data(vardef);

                  if not try_to_consume(_SEMICOLON) then
                    break;
                end;
          end;
        consume(_RKLAMMER);
      end;


    procedure TNodeTreeTypedConstBuilder.tc_emit_orddef(def: TOrdDef; var node: TNode);
      begin
        addstatement(statmnt,CAssignmentNode.Create_Internal(basenode,node));
        basenode:=nil;
        node:=nil;
      end;


    procedure TNodeTreeTypedConstBuilder.tc_emit_floatdef(def: TFloatDef; var node: TNode);
      begin
        addstatement(statmnt,CAssignmentNode.Create_Internal(basenode,node));
        basenode:=nil;
        node:=nil;
      end;


    procedure TNodeTreeTypedConstBuilder.tc_emit_classrefdef(def: TClassRefDef; var node: TNode);
      begin
        addstatement(statmnt,CAssignmentNode.Create_Internal(basenode,node));
        basenode:=nil;
        node:=nil;
      end;


    procedure TNodeTreeTypedConstBuilder.tc_emit_pointerdef(def: TPointerDef; var node: TNode);
      begin
        addstatement(statmnt,CAssignmentNode.Create_Internal(basenode,node));
        basenode:=nil;
        node:=nil;
      end;


    procedure TNodeTreeTypedConstBuilder.tc_emit_setdef(def: TSetDef; var node: TNode);
      begin
        addstatement(statmnt,CAssignmentNode.Create_Internal(basenode,node));
        basenode:=nil;
        node:=nil;
      end;


    procedure TNodeTreeTypedConstBuilder.tc_emit_enumdef(def: TEnumDef; var node: TNode);
      begin
        addstatement(statmnt,CAssignmentNode.Create_Internal(basenode,node));
        basenode:=nil;
        node:=nil;
      end;


    procedure TNodeTreeTypedConstBuilder.tc_emit_stringdef(def: TStringDef; var node: TNode);
      begin
        addstatement(statmnt,CAssignmentNode.Create_Internal(basenode,node));
        basenode:=nil;
        node:=nil;
      end;


    constructor TNodeTreeTypedConstBuilder.create(sym: TStaticVarSym; previnit: TNode);
      begin
        inherited create(sym);
        basenode:=CLoadNode.create(sym,sym.owner);
        resultblock:=internalstatements(statmnt);
        if Assigned(previnit) then
          addstatement(statmnt,previnit);
      end;


    destructor TNodeTreeTypedConstBuilder.Destroy;
      begin
        freeandnil(basenode);
        freeandnil(resultblock);
        inherited Destroy;
      end;


    function TNodeTreeTypedConstBuilder.parse_into_nodetree: TNode;
      begin
        read_typed_const_data(tcsym.vardef);
        result:=self.resultblock;
        self.resultblock:=nil;
      end;

begin
  { default to asmlist version, best for most targets }
  CTypedConstBuilder:=TAsmListTypedConstBuilder;
end.
