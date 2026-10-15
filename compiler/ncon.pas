{
    Copyright (c) 2000-2002 by Florian Klaempfl

    Type checking and register allocation for constants

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
unit ncon;

{$i fpcdefs.inc}

interface

    uses
      tpcompilerreal,
      globtype,widestr,constexp,
      node,
      aasmbase,aasmcnst,cpuinfo,globals,
      symconst,symtype,symdef,symsym;

    type
       tconstnode = class abstract(TNode)
         { directly emit a node's constant data as a constant and return the
           amount of data written }
         function emit_data(tcb:ttai_typedconstbuilder):sizeint;virtual;abstract;
       end;

       trealconstnode = class(tconstnode)
        private
          FCurrencyRange: (crValid, crPositiveLimit, crOverflow);
        public
          typedef : TDef;
          typedefderef : TDeref;
          value_real : bestreal;
          value_currency : currency;
          lab_real : tasmlabel;
          constructor create(v : bestreal;def:TDef);virtual;
          constructor create_currency_scalar(def:TDef);
          function CurrencyScaledValue: Int64;
          procedure SetCurrencyValue(const AValue: bestreal);
          procedure SetCurrencyLiteral(const AText: ShortString);
          procedure NegateValue;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderefimpl;override;
          procedure derefimpl;override;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function simplify(forinline : boolean) : TNode;override;
          function docompare(p: TNode) : boolean; override;
          procedure printnodedata(var t:text);override;
          function emit_data(tcb:ttai_typedconstbuilder):sizeint; override;
{$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeData(var T: Text); override;
{$endif DEBUG_NODE_XML}
       end;
       trealconstnodeclass = class of trealconstnode;

       tordconstnode = class(tconstnode)
          typedef : TDef;
          typedefderef : TDeref;
          value : TConstExprInt;
          rangecheck : boolean;
          { create an ordinal constant node of the specified type and value.
            _rangecheck determines if the value of the ordinal should be checked
            against the ranges of the type definition.
          }
          constructor create(const v : tconstexprint;def:TDef; _rangecheck : boolean);virtual;
          constructor create_currency_scalar(def:TDef);
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderefimpl;override;
          procedure derefimpl;override;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function docompare(p: TNode) : boolean; override;
          procedure printnodedata(var t:text);override;
          function emit_data(tcb:ttai_typedconstbuilder):sizeint; override;
{$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeInfo(var T: Text); override;
          procedure XMLPrintNodeData(var T: Text); override;
{$endif DEBUG_NODE_XML}
       end;
       tordconstnodeclass = class of tordconstnode;

       tpointerconstnode = class(tconstnode)
          typedef : TDef;
          typedefderef : TDeref;
          value   : TConstPtrUInt;
          constructor create(v : TConstPtrUInt;def:TDef);virtual;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderefimpl;override;
          procedure derefimpl;override;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function docompare(p: TNode) : boolean; override;
          procedure printnodedata(var t : text); override;
          function emit_data(tcb:ttai_typedconstbuilder):sizeint; override;
{$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeData(var T: Text); override;
{$endif DEBUG_NODE_XML}
       end;
       tpointerconstnodeclass = class of tpointerconstnode;

       tconststringtype = (
         cst_conststring,
         cst_shortstring,
         cst_longstring,
         cst_ansistring,
         cst_widestring,
         cst_unicodestring
       );

       { tstringconstnode }

       tstringconstnode = class(tconstnode)
          valueas : TAnsiCharDynArray;
          valuews : tcompilerwidestring;
          len     : longint;
          lab_str : tasmlabel;
          astringdef : TDef;
          astringdefderef : TDeref;
          cst_type : tconststringtype;
          constructor createstr(const s : string);virtual;
          constructor createpchar(s: pchar; l: longint; def: TDef);virtual;
          constructor createunistr(w : tcompilerwidestring);virtual;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderefimpl;override;
          procedure derefimpl;override;
          destructor destroy;override;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function getpcharcopy : pchar;
          function docompare(p: TNode) : boolean; override;
          procedure changestringtype(def:TDef);
          function fullcompare(p: tstringconstnode): longint;
          function emit_data(tcb:ttai_typedconstbuilder):sizeint; override;
          function asrawbytestring: rawbytestring;
          function asconstpchar : pchar; inline;
          { returns whether this platform uses the nil pointer to represent
            empty dynamic strings }
          class function emptydynstrnil: boolean; virtual;
          procedure printnodedata(var T: Text); override;
{$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeData(var T: Text); override;
{$endif DEBUG_NODE_XML}
       end;
       tstringconstnodeclass = class of tstringconstnode;

       tsetconstnode = class(TUnaryNode)
          typedef : TDef;
          typedefderef : TDeref;
          value_set : PConstSet;
          lab_set : tasmsymbol;
          constructor create(s : PConstSet;def:TDef);virtual;
          destructor destroy;override;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderefimpl;override;
          procedure derefimpl;override;
          procedure adjustforsetbase;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function docompare(p: TNode) : boolean; override;
          function elements : AInt;
          function low : AInt;
          function high : AInt;
          function emit_data(tcb:ttai_typedconstbuilder):sizeint;
       end;
       tsetconstnodeclass = class of tsetconstnode;

       tnilnode = class(tconstnode)
          constructor create;virtual;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function emit_data(tcb:ttai_typedconstbuilder):sizeint; override;
       end;
       tnilnodeclass = class of tnilnode;

       tguidconstnode = class(tconstnode)
          value : tguid;
          lab_set : tasmsymbol;
          constructor create(const g:tguid);virtual;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function docompare(p: TNode) : boolean; override;
          function emit_data(tcb:ttai_typedconstbuilder):sizeint; override;
       end;
       tguidconstnodeclass = class of tguidconstnode;

    var
       crealconstnode : trealconstnodeclass = trealconstnode;
       cordconstnode : tordconstnodeclass = tordconstnode;
       cpointerconstnode : tpointerconstnodeclass = tpointerconstnode;
       cstringconstnode : tstringconstnodeclass = tstringconstnode;
       csetconstnode : tsetconstnodeclass = tsetconstnode;
       cguidconstnode : tguidconstnodeclass = tguidconstnode;
       cnilnode : tnilnodeclass=tnilnode;

    { Creates tordconstnode with the smallest possible int type which can hold v }
    function genintconstnode(const v : TConstExprInt) : tordconstnode; overload;
    { Creates tordconstnode with the preferredinttype type or a bigger type which can hold v }
    function genintconstnode(const v : TConstExprInt; preferredinttype : TDef) : tordconstnode; overload;
    function genenumnode(v : TEnumSym) : tordconstnode;

    { some helper routines }
    function get_ordinal_value(p : TNode) : TConstExprInt;
    function get_string_value(p : TNode; def: TStringDef) : tstringconstnode;
    function is_constresourcestringnode(p : TNode) : boolean;
    function is_emptyset(p : TNode):boolean;
    function genconstsymtree(p : TConstSym) : TNode;

    function getbooleanvalue(p : TNode) : boolean;

implementation

    uses
      cutils,utcurrencyparse,
      verbose,systems,sysutils,ppu,
      defcmp,defutil,procinfo,
      aasmdata,aasmtai,
      cgbase,
      nld,nbas,ncnv,nmat;

    function genintconstnode(const v : TConstExprInt) : tordconstnode;
      var
        htype : TDef;
      begin
         int_to_type(v,htype);
         genintconstnode:=cordconstnode.create(v,htype,true);
      end;


    function genintconstnode(const v : TConstExprInt; preferredinttype : TDef) : tordconstnode;
      var
        htype : TDef;
      begin
        int_to_type(v,htype);
        if htype.size<preferredinttype.size then
          htype:=preferredinttype;
        result:=cordconstnode.create(v,htype,true);
      end;


    function genenumnode(v : TEnumSym) : tordconstnode;
      var
        htype : TDef;
      begin
         htype:=v.definition;
         genenumnode:=cordconstnode.create(int64(v.value),htype,true);
      end;


    function get_ordinal_value(p : TNode) : TConstExprInt;
      begin
        get_ordinal_value:=0;
        if is_constnode(p) then
          begin
            if p.nodetype=ordconstn then
              get_ordinal_value:=tordconstnode(p).value
            else
              Message(type_e_ordinal_expr_expected);
          end
        else
          Message(type_e_constant_expr_expected);
      end;

    function get_string_value(p: TNode; def: TStringDef): tstringconstnode;
      var
        stringVal: string;
        pWideStringVal: tcompilerwidestring;
      begin
        stringVal:='';
        if is_constcharnode(p) then
          begin
            SetLength(stringVal,1);
            stringVal[1]:=char(tordconstnode(p).value.uvalue);
            result:=cstringconstnode.createstr(stringVal);
          end
        else if is_constwidecharnode(p) then
          begin
            initwidestring(pWideStringVal);
            concatwidestringchar(pWideStringVal, tcompilerwidechar(tordconstnode(p).value.uvalue));
            result:=cstringconstnode.createunistr(pWideStringVal);
          end
        else if p.nodetype=stringconstn then
          result:=tstringconstnode(p.getcopy)
        else
          begin
            Message(type_e_string_expr_expected);
            stringVal:='';
            result:=cstringconstnode.createstr(stringVal);
          end;
        result.changestringtype(def);
      end;


    function is_constresourcestringnode(p : TNode) : boolean;
      begin
        is_constresourcestringnode:=(p.nodetype=loadn) and
          (tloadnode(p).symtableentry.typ=constsym) and
          (TConstSym(tloadnode(p).symtableentry).consttyp in [constresourcestring,constwresourcestring]);
      end;


    function is_emptyset(p : TNode):boolean;
      begin
        is_emptyset:=(p.nodetype=setconstn) and
                     (Tsetconstnode(p).value_set^=[]);
      end;


    function genconstsymtree(p : TConstSym) : TNode;
      var
        p1  : TNode;
        len : longint;
        pc  : pchar;
        value_set : PConstSet;
      begin
        p1:=nil;
        case p.consttyp of
          constord :
            begin
              if p.constdef=nil then
                internalerror(200403232);
              { no range checking; if it has a fixed type, the necessary value
                truncation was already performed at the declaration time }
              p1:=cordconstnode.create(p.value.valueord,p.constdef,false);
            end;
          conststring :
            begin
              len:=p.value.len;
              if not(cs_refcountedstrings in CurrentSettings.localswitches) and (len>255) then
                begin
                  message(parser_e_string_const_too_long);
                  len:=255;
                end;
              getmem(pc,len+1);
              move(pchar(p.value.valueptr)^,pc^,len);
              pc[len]:=#0;
              p1:=cstringconstnode.createpchar(pc,len,p.constdef);
              freemem(pc);
            end;
          constwstring :
            p1:=cstringconstnode.createunistr(p.value.valuews);
          constreal :
            begin
              if (sp_generic_para in p.symoptions) and not (sp_generic_const in p.symoptions) then
                p1:=crealconstnode.create(default(bestreal),p.constdef)
              else
                p1:=crealconstnode.create(pbestreal(p.value.valueptr)^,p.constdef);
            end;
          constset :
            begin
              if sp_generic_const in p.symoptions then
                begin
                  new(value_set);
                  value_set^:=PConstSet(p.value.valueptr)^;
                  p1:=csetconstnode.create(value_set,p.constdef);
                end
              else if sp_generic_para in p.symoptions then
                begin
                  new(value_set);
                  p1:=csetconstnode.create(value_set,p.constdef);
                end
              else
                p1:=csetconstnode.create(PConstSet(p.value.valueptr),p.constdef);
            end;
          constpointer :
            begin
              if sp_generic_para in p.symoptions then
                p1:=cpointerconstnode.create(default(tconstptruint),p.constdef)
              else
                p1:=cpointerconstnode.create(p.value.valueordptr,p.constdef);
            end;
          constnil :
            p1:=cnilnode.create;
          constguid :
            begin
              if sp_generic_para in p.symoptions then
                p1:=cguidconstnode.create(default(tguid))
              else
                p1:=cguidconstnode.create(pguid(p.value.valueptr)^);
            end;
          constnone :
            p1:=cnothingnode.create
          else
            internalerror(200205103);
        end;

        if is_currency(p.constdef) then
          Include(p1.flags, nf_is_currency);

        { transfer generic param flag from symbol to node }
        if sp_generic_para in p.symoptions then
          include(p1.flags,nf_generic_para);
        genconstsymtree:=p1;
      end;


    function getbooleanvalue(p : TNode) : boolean;
      begin
        if is_constboolnode(p) then
          result:=tordconstnode(p).value<>0
        else
          internalerror(2013111601);
      end;

{*****************************************************************************
                             TREALCONSTNODE
*****************************************************************************}

    { generic code     }
    { overridden by:   }
    {   i386           }
    constructor trealconstnode.create(v : bestreal;def:TDef);
      begin
         if CurrentSettings.fputype=fpu_none then
            internalerror(2008022401);
         if def.typ<>floatdef then
           InternalError(2002022402);
         inherited create(realconstn);
         typedef:=def;
         SetCurrencyValue(v);
         case TFloatDef(def).floattype of
           s32real:
             v:=Single(v);
           s64real:
             v:=Double(v);
           s80real,
           sc80real,
           s64comp,
           s64currency:
               ; { Keep the host's native precision. }
         end;
         value_real:=v;
         lab_real:=nil;
      end;

    constructor trealconstnode.create_currency_scalar(def:TDef);
      begin
        Create(10000.0,def);
        Include(flags,nf_internal);
        Include(flags,nf_is_currency);
      end;


    function trealconstnode.CurrencyScaledValue: Int64;
      begin
        if nf_is_currency in flags then
          Result:=Round(value_real)
        else
          begin
            if FCurrencyRange<>crValid then
              CGMessage(parser_e_range_check_error);
            Move(value_currency,Result,SizeOf(Result));
          end;
      end;

    procedure trealconstnode.SetCurrencyValue(const AValue: bestreal);
      var
        lScaled: bestreal;
        lRaw: Int64;
      begin
        lScaled:=AValue*bestreal(10000);
        FCurrencyRange:=crValid;
        if lScaled=bestreal(QWord($8000000000000000)) then
          begin
            { The parser sees this magnitude before unary minus. }
            FCurrencyRange:=crPositiveLimit;
            lRaw:=Low(Int64);
          end
        else
          begin
            if not is_number_float(lScaled) or
               (lScaled>=bestreal(QWord($8000000000000000))) or
               (lScaled<bestreal(Low(Int64))) then
              begin
                FCurrencyRange:=crOverflow;
                lRaw:=0;
              end
            else
              lRaw:=Round(lScaled);
          end;
        Move(lRaw,value_currency,SizeOf(lRaw));
      end;

    procedure trealconstnode.SetCurrencyLiteral(const AText: ShortString);
      var
        lCode: Integer;
        lRaw: Int64;
      begin
        value_currency:=ParseCurrencyLiteral(AText,lCode);
        if lCode=0 then
          FCurrencyRange:=crValid
        else
          begin
            FCurrencyRange:=crOverflow;
            { Preserve the unsigned magnitude of Low(Int64) until unary minus.
              Parse decimal digits directly, including on Double-only hosts. }
            if (Length(AText)<255) and (AText<>'') and (AText[1]<>'-') then
              begin
                value_currency:=ParseCurrencyLiteral('-'+AText,lCode);
                Move(value_currency,lRaw,SizeOf(lRaw));
                if (lCode=0) and (lRaw=Low(Int64)) then
                  FCurrencyRange:=crPositiveLimit;
              end;
          end;
      end;

    procedure trealconstnode.NegateValue;
      var
        lRaw: Int64;
      begin
        value_real:=-value_real;
        Move(value_currency,lRaw,SizeOf(lRaw));
        if FCurrencyRange=crPositiveLimit then
          FCurrencyRange:=crValid
        else if (FCurrencyRange=crValid) and (lRaw=Low(Int64)) then
          FCurrencyRange:=crPositiveLimit;
        {$push}{$Q-}
        lRaw:=-lRaw;
        {$pop}
        Move(lRaw,value_currency,SizeOf(lRaw));
      end;

    constructor trealconstnode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      var
        i : int64;
      begin
        inherited ppuload(t,ppufile);
        ppufile.getderef(typedefderef);
        value_real:=ppufile.getreal;
        i:=ppufile.getint64;
        value_currency:=PCurrency(@i)^;
        FCurrencyRange:=crValid;
        case ppufile.getbyte of
          1: FCurrencyRange:=crPositiveLimit;
          2: FCurrencyRange:=crOverflow;
        end;
        lab_real:=tasmlabel(ppufile.getasmsymbol);
      end;


    procedure trealconstnode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.putderef(typedefderef);
        ppufile.putreal(value_real);
        ppufile.putint64(PInt64(@value_currency)^);
        ppufile.putbyte(Ord(FCurrencyRange));
        ppufile.putasmsymbol(lab_real);
      end;


    procedure trealconstnode.buildderefimpl;
      begin
        inherited buildderefimpl;
        typedefderef.build(typedef);
      end;


    procedure trealconstnode.derefimpl;
      begin
        inherited derefimpl;
        typedef:=TDef(typedefderef.resolve);
      end;


    function trealconstnode.dogetcopy : TNode;
      var
         n : trealconstnode;
      begin
         n:=trealconstnode(inherited dogetcopy);
         n.typedef:=typedef;
         n.value_real:=value_real;
         n.value_currency:=value_currency;
         n.FCurrencyRange:=FCurrencyRange;
         n.lab_real:=lab_real;
         dogetcopy:=n;
      end;


    function trealconstnode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=typedef;

        { range checking? }
        if floating_point_range_check_error or
           (TFloatDef(resultdef).floattype in [s64comp,s64currency]) then
          begin
            { use CGMessage so that the resultdef will get set to errordef
              by pass1.typecheckpass_internal if a range error was triggered,
              which in turn will prevent any potential parent type conversion
              node from creating a new realconstnode with this exact same value
              and hence trigger the same error again }
            case TFloatDef(resultdef).floattype of
              s32real :
                begin
                  if Single(value_real)=MathInf.Value then
                    CGMessage(parser_e_range_check_error);
                end;
              s64real:
                begin
                  if Double(value_real)=MathInf.Value then
                    CGMessage(parser_e_range_check_error);
                end;
              s80real,
              sc80real:
                begin
                  if value_real=MathInf.Value then
                    CGMessage(parser_e_range_check_error);
                end;
              s64comp,
              s64currency:
                begin
                  if (value_real>bestreal(High(Int64))) or
                     (value_real<bestreal(Low(Int64))) then
                    CGMessage(parser_e_range_check_error)
                end;
            end;
          end;
      end;


    function trealconstnode.pass_1 : TNode;
      begin
         result:=nil;
         expectloc:=LOC_CREFERENCE;
      end;


    function trealconstnode.simplify(forinline : boolean) : TNode;
      begin
        result:=nil;
        if (Frac(value_real)<>0.0) and is_currency(resultdef) and not (nf_is_currency in flags) then
          begin
            { Unfortunately we can't safely store unscaled Currency values with
              fractional components in a cross-platform way, so scale it here
              so its 4 decimal places are preserved }
            value_real:=value_real*BestReal(10000.0);
            Include(flags,nf_is_currency);
            Include(flags,nf_internal);
          end;
      end;


    function trealconstnode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          { this should be always true }
          (trealconstnode(p).typedef.typ=floatdef) and (typedef.typ=floatdef) and
          (TFloatDef(typedef).floattype = TFloatDef(trealconstnode(p).typedef).floattype) and
          (
           (
            (TFloatDef(typedef).floattype=s64currency) and
            (CurrencyScaledValue=trealconstnode(p).CurrencyScaledValue)
           )
           or
           (
            (TFloatDef(typedef).floattype<>s64currency) and
            (value_real=trealconstnode(p).value_real) and
            (
              { Make sure 0.0 and -0.0 are not equated unless fastmath is enabled }
              (cs_opt_fastmath in CurrentSettings.optimizerswitches) or
              not (
                (
                  IsPosZero(value_real) and
                  IsNegZero(trealconstnode(p).value_real)
                ) or
                (
                  IsNegZero(value_real) and
                  IsPosZero(trealconstnode(p).value_real)
                )
              )
            ) and
            { floating point compares for non-numbers give strange results usually }
            is_number_float(value_real) and
            is_number_float(trealconstnode(p).value_real)
           )
          );
      end;


    procedure trealconstnode.printnodedata(var t: text);
      begin
        inherited printnodedata(t);
        write(t,printnodeindention,'value = ',realtostr(value_real));
        if is_currency(resultdef) then
          writeln(t,', value_currency = ',value_currency)
        else
          writeln(t);
      end;

    function trealconstnode.emit_data(tcb:ttai_typedconstbuilder):sizeint;
      begin
        case TFloatDef(typedef).floattype of
          s32real:
            tcb.emit_tai(tai_realconst.create_s32real(Single(value_real)),typedef);
          s64real:
            tcb.emit_tai(tai_realconst.create_s64real(Double(value_real)),typedef);
          s80real:
            tcb.emit_tai(tai_realconst.create_s80real(value_real,s80floattype.size),typedef);
          sc80real:
            tcb.emit_tai(tai_realconst.create_s80real(value_real,sc80floattype.size),typedef);
          s64comp:
            { the round is necessary for native compilers where comp isn't a float }
            tcb.emit_tai(tai_realconst.create_s64compreal(Round(value_real)),typedef);
          s64currency:
            { Lowered Currency nodes already contain the integer payload. }
            tcb.emit_tai(tai_realconst.create_s64compreal(Round(value_real)),typedef);
        end;
        result:=resultdef.size;
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TRealConstNode.XMLPrintNodeData(var T: Text);
      begin
        inherited XMLPrintNodeData(T);
        WriteLn(T, printnodeindention, '<value>', realtostr(value_real), '</value>');
      end;
{$endif DEBUG_NODE_XML}

{*****************************************************************************
                              TORDCONSTNODE
*****************************************************************************}

    constructor tordconstnode.create(const v : tconstexprint;def:TDef;_rangecheck : boolean);

      begin
         inherited create(ordconstn);
         value:=v;
         typedef:=def;
         rangecheck := _rangecheck;
      end;


    constructor tordconstnode.create_currency_scalar(def:TDef);
      begin
        Create(10000,def,false);
        Include(flags,nf_internal);
        Include(flags,nf_is_currency);
      end;


    constructor tordconstnode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.getderef(typedefderef);
        value:=ppufile.getexprint;
        { normally, the value is already compiled, so we don't need
          to do once again a range check
        }
        rangecheck := false;
      end;


    procedure tordconstnode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.putderef(typedefderef);
        ppufile.putexprint(value);
      end;


    procedure tordconstnode.buildderefimpl;
      begin
        inherited buildderefimpl;
        typedefderef.build(typedef);
      end;


    procedure tordconstnode.derefimpl;
      begin
        inherited derefimpl;
        typedef:=TDef(typedefderef.resolve);
      end;


    function tordconstnode.dogetcopy : TNode;

      var
         n : tordconstnode;

      begin
         n:=tordconstnode(inherited dogetcopy);
         n.value:=value;
         n.typedef := typedef;
         dogetcopy:=n;
      end;

    function tordconstnode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=typedef;
        { only do range checking when explicitly asked for it
          and if the type can be range checked, see tests/tbs/tb0539.pas }
        if (resultdef.typ in [orddef,enumdef]) and not(nf_generic_para in flags) then
          adaptrange(resultdef,value,nf_internal in flags,not rangecheck,rangecheck)
      end;

    function tordconstnode.pass_1 : TNode;
      begin
         result:=nil;
         expectloc:=LOC_CONSTANT;
      end;

    function tordconstnode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (value = tordconstnode(p).value) and
          equal_defs(typedef,tordconstnode(p).typedef);
      end;


    procedure tordconstnode.printnodedata(var t: text);
      begin
        inherited printnodedata(t);
        writeln(t,printnodeindention,'typedef = "',typedef.GetTypeName,'"');
        writeln(t,printnodeindention,'value = ',tostr(value));
      end;

    function tordconstnode.emit_data(tcb:ttai_typedconstbuilder):sizeint;
      begin
        tcb.emit_ord_const(value,resultdef);
        result:=resultdef.size;
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TOrdConstNode.XMLPrintNodeInfo(var T: Text);
      begin
        inherited XMLPrintNodeInfo(T);
        Write(T, ' rangecheck="', rangecheck, '"');
      end;


    procedure TOrdConstNode.XMLPrintNodeData(var T: Text);
      begin
        inherited XMLPrintNodeData(T);
        WriteLn(T, printnodeindention, '<value>', tostr(value), '</value>');
      end;
{$endif DEBUG_NODE_XML}

{*****************************************************************************
                            TPOINTERCONSTNODE
*****************************************************************************}

    constructor tpointerconstnode.create(v : TConstPtrUInt;def:TDef);
      begin
        inherited create(pointerconstn);
        value:=v;
        typedef:=def;
      end;


    constructor tpointerconstnode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.getderef(typedefderef);
        value:=ppufile.getptruint;
      end;


    procedure tpointerconstnode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.putderef(typedefderef);
        ppufile.putptruint(value);
      end;


    procedure tpointerconstnode.buildderefimpl;
      begin
        inherited buildderefimpl;
        typedefderef.build(typedef);
      end;


    procedure tpointerconstnode.derefimpl;
      begin
        inherited derefimpl;
        typedef:=TDef(typedefderef.resolve);
      end;


    function tpointerconstnode.dogetcopy : TNode;
      var
         n : tpointerconstnode;
      begin
        n:=tpointerconstnode(inherited dogetcopy);
        n.value:=value;
        n.typedef := typedef;
        dogetcopy:=n;
      end;


    function tpointerconstnode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=typedef;
        if is_voidpointer(resultdef) and (value=0) then
          result:=cnilnode.create;
      end;


    function tpointerconstnode.pass_1 : TNode;
      begin
        result:=nil;
        expectloc:=LOC_CONSTANT;
      end;


    function tpointerconstnode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (value = tpointerconstnode(p).value);
      end;


    procedure tpointerconstnode.printnodedata(var t : text);
      begin
        inherited printnodedata(t);
        writeln(t,printnodeindention,'value = $',hexstr(PUInt(value),sizeof(PUInt)*2));
      end;

    function tpointerconstnode.emit_data(tcb: ttai_typedconstbuilder): sizeint;
      begin
        if TPointerDef(resultdef).compatible_with_pointerdef_size(TPointerDef(voidpointertype)) then
          tcb.emit_tai(tai_const.Create_int_dataptr(value),voidpointertype)
        else
          tcb.emit_tai(tai_const.Create_int_codeptr(value),voidcodepointertype);
        result:=resultdef.size;
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TPointerConstNode.XMLPrintNodeData(var T: Text);
      begin
        inherited XMLPrintNodeData(T);
        WriteLn(T, PrintNodeIndention, '<value>$', hexstr(PUInt(value),sizeof(PUInt)*2), '</value>');
      end;
{$endif DEBUG_NODE_XML}

{*****************************************************************************
                             TSTRINGCONSTNODE
*****************************************************************************}

    constructor tstringconstnode.createstr(const s : string);
      var
         l : longint;
      begin
         inherited create(stringconstn);
         l:=length(s);
         len:=l;
         { stringdup write even past a #0 }
         setlength(valueas,l+1);
         valueas[l]:=#0;
         if l>0 then
           move(s[1],valueas[0],l);
         lab_str:=nil;
         cst_type:=cst_conststring;
      end;


    constructor tstringconstnode.createunistr(w : tcompilerwidestring);
      begin
         inherited create(stringconstn);
         len:=getlengthwidestring(w);
         initwidestring(valuews);
         copywidestring(w,valuews);
         lab_str:=nil;
         cst_type:=cst_unicodestring;
      end;


    constructor tstringconstnode.createpchar(s: pchar; l: longint; def: TDef);
      begin
         inherited create(stringconstn);
         len:=l;
         setlength(valueas,l+1);
         valueas[l]:=#0;
         if l>0 then
           move(s[0],valueas[0],l);
         if assigned(def) and
            is_ansistring(def) then
           begin
             cst_type:=cst_ansistring;
             astringdef:=def;
           end
         else
           cst_type:=cst_conststring;
         lab_str:=nil;
      end;


    destructor tstringconstnode.destroy;
      begin
        if cst_type in [cst_widestring,cst_unicodestring] then
          donewidestring(valuews)
        else
          valueas:=nil;
        inherited destroy;
      end;


    constructor tstringconstnode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      var
        i : longint;
      begin
        inherited ppuload(t,ppufile);
        cst_type:=tconststringtype(ppufile.getbyte);
        len:=ppufile.getlongint;
        if cst_type in [cst_widestring,cst_unicodestring] then
          begin
            initwidestring(valuews);
            setlengthwidestring(valuews,len);
            { don't use getdata, because the compilerwidechars may have to
              be byteswapped
            }
            for i:=0 to valuews.len-1 do
              valuews.data[i]:=ppufile.getword;
          end
        else
          begin
            setlength(valueas,len+1);
            valueas[len]:=#0;
            if len>0 then
              ppufile.getdata(valueas[0],len);
          end;
        lab_str:=tasmlabel(ppufile.getasmsymbol);
        if cst_type=cst_ansistring then
          ppufile.getderef(astringdefderef);
      end;


    procedure tstringconstnode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.putbyte(byte(cst_type));
        ppufile.putlongint(len);
        if len>0 then
          if cst_type in [cst_widestring,cst_unicodestring] then
            ppufile.putdata(valuews.data[0],len*sizeof(tcompilerwidechar))
          else
            ppufile.putdata(valueas[0],len);
        ppufile.putasmsymbol(lab_str);
        if cst_type=cst_ansistring then
          ppufile.putderef(astringdefderef);
      end;


    procedure tstringconstnode.buildderefimpl;
      begin
        inherited buildderefimpl;
        if cst_type=cst_ansistring then
          astringdefderef.build(astringdef);
      end;


    procedure tstringconstnode.derefimpl;
      begin
        inherited derefimpl;
        if cst_type=cst_ansistring then
          astringdef:=TDef(astringdefderef.resolve);
      end;


    function tstringconstnode.dogetcopy : TNode;

      var
         n : tstringconstnode;

      begin
         n:=tstringconstnode(inherited dogetcopy);
         n.cst_type:=cst_type;
         n.len:=len;
         n.lab_str:=lab_str;
         if cst_type in [cst_widestring,cst_unicodestring] then
           begin
             initwidestring(n.valuews);
             copywidestring(valuews,n.valuews);
           end
         else
           begin
           setlength(n.valueas,len+1);
           n.valueas[len]:=#0;
           if len>0 then
             move(valueas[0],n.valueas[0],len);
           end;
         n.astringdef:=astringdef;
         dogetcopy:=n;
      end;


    function tstringconstnode.pass_typecheck:TNode;
      begin
        result:=nil;
        case cst_type of
          cst_conststring :
            begin
              { handle and store as array[0..len-1] of char }
              resultdef:=carraydef.create(0,len-1,s32inttype);
              TArrayDef(resultdef).elementdef:=cansichartype;
              include(TArrayDef(resultdef).arrayoptions,ado_IsConstString);
            end;
          cst_shortstring :
            resultdef:=cshortstringtype;
          cst_ansistring :
            if not assigned(astringdef) then
              resultdef:=getansistringdef
            else
              resultdef:=astringdef;
          cst_unicodestring :
            resultdef:=cunicodestringtype;
          cst_widestring :
            resultdef:=cwidestringtype;
          cst_longstring :
            resultdef:=clongstringtype;
        end;
      end;


    function tstringconstnode.pass_1 : TNode;
      begin
        result:=nil;
        if (cst_type in [cst_ansistring,cst_widestring,cst_unicodestring]) then
          begin
            if len=0 then
              expectloc:=LOC_CONSTANT
            else
              expectloc:=LOC_REGISTER
          end
        else
          expectloc:=LOC_CREFERENCE;
      end;


    function tstringconstnode.getpcharcopy : pchar;
      var
         pc : pchar;
      begin
         pc:=nil;
         getmem(pc,len+1);
         if pc=nil then
           Message(general_f_no_memory_left);
         pc[len]:=#0;
         if len>0 then
           move(valueas[0],pc^,len);
         getpcharcopy:=pc;
      end;

    function tstringconstnode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (len = tstringconstnode(p).len) and
          (lab_str = tstringconstnode(p).lab_str) and
          { This is enough as soon as labels are allocated, otherwise }
          { fall back to content compare.                             }
          (assigned(lab_str) or
            (cst_type = tstringconstnode(p).cst_type) and
            (fullcompare(tstringconstnode(p)) = 0))
          ;
      end;


    procedure tstringconstnode.changestringtype(def:TDef);
      const
        st2cst : array[TStringType] of tconststringtype = (
          cst_shortstring,cst_longstring,cst_ansistring,cst_widestring,cst_unicodestring);
      var
        pw : tcompilerwidestring;
        pc : pchar;
        cp1 : TStringEncoding;
        cp2 : TStringEncoding;
        l,l2 : longint;
      begin
        if def.typ<>stringdef then
          internalerror(200510011);
        { convert ascii 2 unicode }
        if (TStringDef(def).stringtype in [st_widestring,st_unicodestring]) and
           not(cst_type in [cst_widestring,cst_unicodestring]) then
          begin
            initwidestring(valuews);
            ascii2unicode(asconstpchar,len,CurrentSettings.sourcecodepage,valuews);
          end
        else
          { convert unicode 2 ascii }
          if (cst_type in [cst_widestring,cst_unicodestring]) and
            not(TStringDef(def).stringtype in [st_widestring,st_unicodestring]) then
            begin
              cp1:=TStringDef(def).encoding;
              if (cp1=globals.CP_NONE) or (cp1=0) then
                cp1:=CurrentSettings.sourcecodepage;
              if (cp1=CP_UTF8) then
                begin
                  l2:=len;
                  l:=UnicodeToUtf8(nil,0,valuews.asconstpunicodechar,l2);
                  setlength(valueas,l+1);
                  valueas[l]:=#0;
                  if l>0 then
                    UnicodeToUtf8(asconstpchar,l,valuews.asconstpunicodechar,l2);
                  len:=l-1;
                  donewidestring(valuews);
                end
              else
                begin
                  setlength(valueas,getlengthwidestring(valuews)+1);
                  len:=Length(valueas)-1;
                  unicode2ascii(valuews,asconstpchar,cp1);
                  donewidestring(valuews);
                end;
            end
        else
          if (TStringDef(def).stringtype = st_ansistring) and
             not(cst_type in [cst_widestring,cst_unicodestring]) then
            begin
              cp1:=TStringDef(def).encoding;
              if cp1=0 then
                cp1:=CurrentSettings.sourcecodepage;
              if (cst_type = cst_ansistring) then
                begin
                  cp2:=TStringDef(resultdef).encoding;
                  if cp2=0 then
                    cp2:=CurrentSettings.sourcecodepage;
                end
              else if (cst_type in [cst_shortstring,cst_conststring,cst_longstring]) then
                cp2:=CurrentSettings.sourcecodepage
              else
                internalerror(2013112916);
              { don't change string if codepages are equal or string length is 0 }
              if (cp1<>cp2) and (len>0) then
                begin
                  if cpavailable(cp1) and cpavailable(cp2) then
                    changecodepage(asconstpchar,len,cp2,asconstpchar,cp1)
                  else if (cp1 <> globals.CP_NONE) and (cp2 <> globals.CP_NONE) then
                    begin
                      { if source encoding is UTF8 convert using UTF8->UTF16->destination encoding }
                      if (cp2=CP_UTF8) then
                        begin
                          if not cpavailable(cp1) then
                            begin
                              Message1(option_code_page_not_available,IntToStr(cp1));
                              exit;
                            end;
                          initwidestring(pw);
                          setlengthwidestring(pw,len);
                          { returns room for terminating 0 }
                          if len>0 then
                            l:=Utf8ToUnicode(pw.asconstpunicodechar,len,asconstpchar,len)
                          else
                            l:=1;
                          if (l<>getlengthwidestring(pw)) then
                            begin
                              setlengthwidestring(pw,l);
                              setlength(valueas,l);
                              valueas[l-1]:=#0;
                            end;
                          unicode2ascii(pw,valueas,cp1);
                          len:=l-1;
                          donewidestring(pw);
                        end
                      else
                      { if destination encoding is UTF8 convert using source encoding->UTF16->UTF8 }
                      if (cp1=CP_UTF8) then
                        begin
                          if not cpavailable(cp2) then
                            begin
                              Message1(option_code_page_not_available,IntToStr(cp2));
                              exit;
                            end;
                          initwidestring(pw);
                          setlengthwidestring(pw,len);
                          ascii2unicode(asconstpchar,len,cp2,pw);
                          { returns room for terminating 0 }
                          l:=UnicodeToUtf8(nil,0,pw.asconstpunicodechar,len);
                          if l<>len then
                            begin
                            setlength(valueas,l);
                            valueas[l-1]:=#0;
                            end;
                          UnicodeToUtf8(asconstpchar,l,pw.asconstpunicodechar,len);
                          len:=l-1;
                          donewidestring(pw);
                        end
                      else
                        begin
                          { output error message that encoding is not available for the compiler }
                          if not cpavailable(cp1) then
                            Message1(option_code_page_not_available,IntToStr(cp1));
                          if not cpavailable(cp2) then
                            Message1(option_code_page_not_available,IntToStr(cp2));
                        end;
                    end;
                end;
            end;
        cst_type:=st2cst[TStringDef(def).stringtype];
        resultdef:=def;
      end;

    function tstringconstnode.fullcompare(p: tstringconstnode): longint;
      begin
        if cst_type<>p.cst_type then
          InternalError(2009121701);
        if cst_type in [cst_widestring,cst_unicodestring] then
          result:=comparewidestrings(valuews,p.valuews)
        else
          result:=compareansistrings(asconstpchar,p.asconstpchar,len,p.len);
      end;

    function tstringconstnode.emit_data(tcb:ttai_typedconstbuilder):sizeint;
      var
        ss : shortstring;
        labofs : tasmlabofs;
        winlikewidestring : boolean;
      begin
        case TStringDef(resultdef).stringtype of
          st_shortstring:
            begin
              setlength(ss,len);
              if len>0 then
                move(valueas[0],ss[1],len);
              tcb.emit_shortstring_const(ss);
              result:=len+1;
            end;
          st_longstring:
            internalerror(2019070801);
          st_ansistring:
            begin
              labofs:=tcb.emit_ansistring_const(CurrentAsmData.asmlists[al_typedconsts],asconstpchar,len,TStringDef(resultdef).encoding);
              tcb.emit_string_offset(labofs,len,TStringDef(resultdef).stringtype,false,charpointertype);
              result:=voidpointertype.size;
            end;
          st_widestring,
          st_unicodestring:
            begin
              winlikewidestring:=(cst_type=cst_widestring) and (tf_winlikewidestring in TargetInfo.flags);
              labofs:=tcb.emit_unicodestring_const(CurrentAsmData.asmlists[al_typedconsts],valuews,TStringDef(resultdef).encoding,winlikewidestring);
              tcb.emit_string_offset(labofs,len,TStringDef(resultdef).stringtype,false,widecharpointertype);
              result:=voidpointertype.size;
            end;
        end;
      end;

    function tstringconstnode.asrawbytestring: rawbytestring;
    begin
      Result:='';
      if Length(valueas)>0 then
        Result:=pchar(@valueas[0]);
    end;

    var
      cEmptyString : ansichar = #0;

    function tstringconstnode.asconstpchar: pchar;
    begin
      if length(valueas)>0 then
        Result:=@valueas[0]
      else
        Result:=@cEmptyString;
    end;

    class function tstringconstnode.emptydynstrnil: boolean;
      begin
        result:=true;
      end;

      procedure tstringconstnode.printnodedata(var T: Text);
      var
        u : unicodestring;

      begin
        inherited printnodedata(t);
        if length(valueas)>0 then
          writeln(t,printnodeindention,'value = "',pAnsichar(@valueas[0]),'"')
        else if assigned(valuews) and (valuews.len>0) then
          begin
          setlength(u,valuews.len);
          move(valuews.data[0],u[1],valuews.len*sizeof(unicodechar));
          writeln(t,printnodeindention,'value = "',u,'"');
          end
        else
          writeln(t,printnodeindention,'value = ""');
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TStringConstNode.XMLPrintNodeData(var T: Text);
      var
        OutputStr: ansistring;
      begin
        inherited XMLPrintNodeData(T);
        Write(T, printnodeindention, '<stringtype>');
        case cst_type of
        cst_conststring:
          Write(T, 'conststring');
        cst_shortstring:
          Write(T, 'shortstring');
        cst_longstring:
          Write(T, 'longstring');
        cst_ansistring:
          Write(T, 'ansistring');
        cst_widestring:
          Write(T, 'widestring');
        cst_unicodestring:
          Write(T, 'unicodestring');
        end;
        WriteLn(T, '</stringtype>');
        WriteLn(T, printnodeindention, '<length>', len, '</length>');

        if len = 0 then
          begin
            WriteLn(T, printnodeindention, '<value />');
            Exit;
          end;

        case cst_type of
        cst_widestring, cst_unicodestring:
          begin
            { value_str is of type PCompilerWideString }
            SetLength(OutputStr, len);
            UnicodeToUtf8(PChar(OutputStr), PUnicodeChar(valuews.data), len + 1); { +1 for the null terminator }
          end;
        else
          OutputStr := PAnsichar(@valueas[0]);
          SetLength(OutputStr, len);
        end;

        WriteLn(T, printnodeindention, '<value>', SanitiseXMLString(OutputStr), '</value>');
      end;
{$endif DEBUG_NODE_XML}

{*****************************************************************************
                             TSETCONSTNODE
*****************************************************************************}

    constructor tsetconstnode.create(s : PConstSet;def:TDef);

      begin
         inherited create(setconstn,nil);
         typedef:=def;
         if assigned(s) then
           begin
              new(value_set);
              value_set^:=s^;
           end
         else
           value_set:=nil;
      end;


    destructor tsetconstnode.destroy;
      begin
        if assigned(value_set) then
         dispose(value_set);
        inherited destroy;
      end;


    constructor tsetconstnode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.getderef(typedefderef);
        new(value_set);
        ppufile.getset(tppuset32(value_set^));
      end;


    procedure tsetconstnode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.putderef(typedefderef);
        ppufile.putset(tppuset32(value_set^));
      end;


    procedure tsetconstnode.buildderefimpl;
      begin
        inherited buildderefimpl;
        typedefderef.build(typedef);
      end;


    procedure tsetconstnode.derefimpl;
      begin
        inherited derefimpl;
        typedef:=TDef(typedefderef.resolve);
      end;

    type
       setbytes = array[0..31] of byte;
       Psetbytes = ^setbytes;

    procedure tsetconstnode.adjustforsetbase;
      var
        i, diff: longint;
      begin
        { Internally, the compiler stores all sets with setbase 0, so we have }
        { to convert the set to its actual format in case setbase<>0 when     }
        { writing it out                                                      }
        if (TSetDef(resultdef).setbase<>0) then
          begin
            if (TSetDef(resultdef).setbase and 7)<>0 then
              internalerror(2007091501);
            diff:=TSetDef(resultdef).setbase div 8;
            { This is endian-neutral in the new set format: in both cases, }
            { the first byte contains the first elements of the set.       }
            { Since the compiler/base rtl cannot contain packed sets before }
            { they work for big endian, it's no problem that the code below }
            { is wrong for the old big endian set format (setbase cannot be }
            { <>0 with non-packed sets).                                    }
            for i:=0 to TSetDef(resultdef).size-1 do
              begin
                Psetbytes(value_set)^[i]:=Psetbytes(value_set)^[i+diff];
                Psetbytes(value_set)^[i+diff]:=0;
              end;
          end;
      end;


    function tsetconstnode.dogetcopy : TNode;
      var
         n : tsetconstnode;
      begin
         n:=tsetconstnode(inherited dogetcopy);
         if assigned(value_set) then
           begin
              new(n.value_set);
              n.value_set^:=value_set^
           end
         else
           n.value_set:=nil;
         n.typedef := typedef;
         n.lab_set:=lab_set;
         dogetcopy:=n;
      end;


    function tsetconstnode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=typedef;
      end;


    function tsetconstnode.pass_1 : TNode;
      begin
         result:=nil;
         if is_smallset(resultdef) then
          expectloc:=LOC_CONSTANT
         else
          expectloc:=LOC_CREFERENCE;
      end;


    function tsetconstnode.docompare(p: TNode): boolean;
      begin
        docompare:=(inherited docompare(p)) and
                   (value_set^=Tsetconstnode(p).value_set^);
      end;


    function tsetconstnode.elements : AInt;
      var
        i : longint;
      begin
        result:=0;
        if not(assigned(value_set)) then
          exit;
        for i:=0 to TSetDef(resultdef).size-1 do
          result:=result+ PopCnt(Psetbytes(value_set)^[i]);
      end;


    function tsetconstnode.low: AInt;
      var
        i: ASizeInt;
      begin
        result:=0;
        if not(assigned(value_set)) then
          exit;
        i:=0;
        while i<=TSetDef(resultdef).setmax do
          begin
            if i in value_set^ then
              begin
                result:=i;
                exit;
              end;
            inc(i);
          end;
      end;


    function tsetconstnode.high: AInt;
      var
        i: ASizeInt;
      begin
        result:=0;
        if not(assigned(value_set)) then
          exit;
        i:=TSetDef(resultdef).setmax;
        while i>=TSetDef(resultdef).setbase do
          begin
            if i in value_set^ then
              begin
                result:=i;
                exit;
              end;
            dec(i);
          end;
      end;


    function tsetconstnode.emit_data(tcb:ttai_typedconstbuilder):sizeint;
      type
        setbytes=array[0..31] of byte;
        Psetbytes=^setbytes;
      var
        setval : aint;
        i : sizeint;
      begin
        if is_smallset(resultdef) then
          begin
            if (SourceInfo.endian=TargetInfo.endian) then
              begin
                { not plongint, because that will "sign extend" the set on 64 bit platforms }
                { if changed to "paword", please also modify "32-resultdef.size*8" and      }
                { cross-endian code below                                                   }
                { Extra aint type cast to avoid range errors                                }
                 setval:=aint(pCardinal(value_set)^)
              end
            else
              begin
                setval:=aint(reverse_longword(Pcardinal(value_set)^));
              end;
            if (TargetInfo.endian=endian_big) then
              setval:=setval shr (32-resultdef.size*8);
            case resultdef.size of
              1:
                tcb.emit_ord_const(byte(setval),u8inttype);
              2:
                tcb.emit_ord_const(word(setval),u16inttype);
              4:
                tcb.emit_ord_const(longword(setval),u32inttype);
              8:
                tcb.emit_ord_const(qword(setval),u64inttype);
              else
                internalerror(2019070802);
            end;
          end
        else
          begin
            if (SourceInfo.endian=TargetInfo.endian) then
              for i:=0 to resultdef.size-1 do
                tcb.emit_tai(tai_const.create_8bit(Psetbytes(value_set)^[i]),u8inttype)
            else
              for i:=0 to resultdef.size-1 do
                tcb.emit_tai(tai_const.create_8bit(reverse_byte(Psetbytes(value_set)^[i])),u8inttype);
          end;
        result:=resultdef.size;
      end;


{*****************************************************************************
                               TNILNODE
*****************************************************************************}

    constructor tnilnode.create;

      begin
        inherited create(niln);
      end;

    function tnilnode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=voidpointertype;
      end;

    function tnilnode.emit_data(tcb: ttai_typedconstbuilder): sizeint;
      begin
        if TPointerDef(resultdef).compatible_with_pointerdef_size(TPointerDef(voidpointertype)) then
          tcb.emit_tai(tai_const.Create_nil_dataptr,voidpointertype)
        else
          tcb.emit_tai(tai_const.Create_nil_codeptr,voidcodepointertype);
        result:=resultdef.size;
      end;

    function tnilnode.pass_1 : TNode;
      begin
        result:=nil;
        expectloc:=LOC_CONSTANT;
      end;

{*****************************************************************************
                            TGUIDCONSTNODE
*****************************************************************************}

    constructor tguidconstnode.create(const g:tguid);

      begin
         inherited create(guidconstn);
         value:=g;
      end;

    constructor tguidconstnode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.getguid(value);
      end;


    procedure tguidconstnode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.putguid(value);
      end;


    function tguidconstnode.dogetcopy : TNode;
      var
         n : tguidconstnode;
      begin
         n:=tguidconstnode(inherited dogetcopy);
         n.value:=value;
         n.lab_set:=lab_set;
         dogetcopy:=n;
      end;


    function tguidconstnode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=rec_tguid;
      end;


    function tguidconstnode.pass_1 : TNode;
      begin
         result:=nil;
         expectloc:=LOC_CREFERENCE;
      end;


    function tguidconstnode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (guid2string(value) = guid2string(tguidconstnode(p).value));
      end;

    function tguidconstnode.emit_data(tcb: ttai_typedconstbuilder): sizeint;
      begin
        tcb.emit_guid_const(value);
        result:=resultdef.size;
      end;

end.
