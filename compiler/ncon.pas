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
      TPCompilerReal,
      GlobType,WideStr,ConstExp,
      node,
      aasmbase,aasmcnst,CPUInfo,Globals,
      symconst,symtype,symdef,SymSym;

    type
       TConstNode = class abstract(TNode)
         { directly emit a node's constant data as a constant and return the
           amount of data written }
         function emit_data(tcb:TTAITypedConstBuilder):sizeint;virtual;abstract;
       end;

       TRealConstNode = class(TConstNode)
        private
          FCurrencyRange: (crValid, crPositiveLimit, crOverflow);
        public
          typedef : TDef;
          TypeDefDeref : TDeref;
          value_real : BestReal;
          value_currency : currency;
          lab_real : TAsmLabel;
          constructor create(v : BestReal;def:TDef);virtual;
          constructor create_currency_scalar(def:TDef);
          function CurrencyScaledValue: Int64;
          procedure SetCurrencyValue(const AValue: BestReal);
          procedure SetCurrencyLiteral(const AText: ShortString);
          procedure NegateValue;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure derefimpl;override;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function simplify(forinline : boolean) : TNode;override;
          function docompare(p: TNode) : boolean; override;
          procedure printnodedata(var t:text);override;
          function emit_data(tcb:TTAITypedConstBuilder):sizeint; override;
{$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeData(var T: Text); override;
{$endif DEBUG_NODE_XML}
       end;
       TRealConstNodeClass = class of TRealConstNode;

       TOrdConstNode = class(TConstNode)
          typedef : TDef;
          TypeDefDeref : TDeref;
          value : TConstExprInt;
          rangecheck : boolean;
          { create an ordinal constant node of the specified type and value.
            _rangecheck determines if the value of the ordinal should be checked
            against the ranges of the type definition.
          }
          constructor create(const v : TConstExprInt;def:TDef; _rangecheck : boolean);virtual;
          constructor create_currency_scalar(def:TDef);
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure derefimpl;override;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function docompare(p: TNode) : boolean; override;
          procedure printnodedata(var t:text);override;
          function emit_data(tcb:TTAITypedConstBuilder):sizeint; override;
{$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeInfo(var T: Text); override;
          procedure XMLPrintNodeData(var T: Text); override;
{$endif DEBUG_NODE_XML}
       end;
       TOrdConstNodeClass = class of TOrdConstNode;

       TPointerConstNode = class(TConstNode)
          typedef : TDef;
          TypeDefDeref : TDeref;
          value   : TConstPtrUInt;
          constructor create(v : TConstPtrUInt;def:TDef);virtual;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure derefimpl;override;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function docompare(p: TNode) : boolean; override;
          procedure printnodedata(var t : text); override;
          function emit_data(tcb:TTAITypedConstBuilder):sizeint; override;
{$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeData(var T: Text); override;
{$endif DEBUG_NODE_XML}
       end;
       TPointerConstNodeClass = class of TPointerConstNode;

       TConstStringType = (
         cst_conststring,
         cst_shortstring,
         cst_longstring,
         cst_ansistring,
         cst_widestring,
         cst_unicodestring
       );

       { tstringconstnode }

       TStringConstNode = class(TConstNode)
          valueas : TAnsiCharDynArray;
          ValueWS : TCompilerWideString;
          len     : LongInt;
          lab_str : TAsmLabel;
          astringdef : TDef;
          astringdefderef : TDeref;
          cst_type : TConstStringType;
          constructor createstr(const s : string);virtual;
          constructor createpchar(s: pchar; l: LongInt; def: TDef);virtual;
          constructor createunistr(w : TCompilerWideString);virtual;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure derefimpl;override;
          destructor Destroy;override;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function getpcharcopy : pchar;
          function docompare(p: TNode) : boolean; override;
          procedure changestringtype(def:TDef);
          function fullcompare(p: TStringConstNode): LongInt;
          function emit_data(tcb:TTAITypedConstBuilder):sizeint; override;
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
       TStringConstNodeClass = class of TStringConstNode;

       TSetConstNode = class(TUnaryNode)
          typedef : TDef;
          TypeDefDeref : TDeref;
          value_set : PConstSet;
          lab_set : TAsmSymbol;
          constructor create(s : PConstSet;def:TDef);virtual;
          destructor Destroy;override;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure derefimpl;override;
          procedure adjustforsetbase;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function docompare(p: TNode) : boolean; override;
          function elements : AInt;
          function low : AInt;
          function high : AInt;
          function emit_data(tcb:TTAITypedConstBuilder):sizeint;
       end;
       TSetConstNodeClass = class of TSetConstNode;

       TNilNode = class(TConstNode)
          constructor create;virtual;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function emit_data(tcb:TTAITypedConstBuilder):sizeint; override;
       end;
       TNilNodeClass = class of TNilNode;

       TGUIDConstNode = class(TConstNode)
          value : TGUID;
          lab_set : TAsmSymbol;
          constructor create(const g:TGUID);virtual;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function docompare(p: TNode) : boolean; override;
          function emit_data(tcb:TTAITypedConstBuilder):sizeint; override;
       end;
       TGUIDConstNodeClass = class of TGUIDConstNode;

    var
       CRealConstNode : TRealConstNodeClass = TRealConstNode;
       COrdConstNode : TOrdConstNodeClass = TOrdConstNode;
       CPointerConstNode : TPointerConstNodeClass = TPointerConstNode;
       CStringConstNode : TStringConstNodeClass = TStringConstNode;
       CSetConstNode : TSetConstNodeClass = TSetConstNode;
       CGUIDConstNode : TGUIDConstNodeClass = TGUIDConstNode;
       CNilNode : TNilNodeClass=TNilNode;

    { Creates tordconstnode with the smallest possible int type which can hold v }
    function genintconstnode(const v : TConstExprInt) : TOrdConstNode; overload;
    { Creates tordconstnode with the preferredinttype type or a bigger type which can hold v }
    function genintconstnode(const v : TConstExprInt; preferredinttype : TDef) : TOrdConstNode; overload;
    function genenumnode(v : TEnumSym) : TOrdConstNode;

    { some helper routines }
    function get_ordinal_value(p : TNode) : TConstExprInt;
    function get_string_value(p : TNode; def: TStringDef) : TStringConstNode;
    function is_constresourcestringnode(p : TNode) : boolean;
    function is_emptyset(p : TNode):boolean;
    function genconstsymtree(p : TConstSym) : TNode;

    function getbooleanvalue(p : TNode) : boolean;

implementation

    uses
      CUtils,utcurrencyparse,
      Verbose,Systems,SysUtils,PPU,
      defcmp,defutil,ProcInfo,
      AAsmData,aasmtai,
      cgbase,
      nld,nbas,ncnv,nmat;

    function genintconstnode(const v : TConstExprInt) : TOrdConstNode;
      var
        htype : TDef;
      begin
         Int_To_Type(v,htype);
         genintconstnode:=COrdConstNode.create(v,htype,true);
      end;


    function genintconstnode(const v : TConstExprInt; preferredinttype : TDef) : TOrdConstNode;
      var
        htype : TDef;
      begin
        Int_To_Type(v,htype);
        if htype.Size<preferredinttype.Size then
          htype:=preferredinttype;
        result:=COrdConstNode.create(v,htype,true);
      end;


    function genenumnode(v : TEnumSym) : TOrdConstNode;
      var
        htype : TDef;
      begin
         htype:=v.definition;
         genenumnode:=COrdConstNode.create(int64(v.Value),htype,true);
      end;


    function get_ordinal_value(p : TNode) : TConstExprInt;
      begin
        get_ordinal_value:=0;
        if is_constnode(p) then
          begin
            if p.nodetype=ordconstn then
              get_ordinal_value:=TOrdConstNode(p).Value
            else
              Message(type_e_ordinal_expr_expected);
          end
        else
          Message(type_e_constant_expr_expected);
      end;

    function get_string_value(p: TNode; def: TStringDef): TStringConstNode;
      var
        stringVal: string;
        pWideStringVal: TCompilerWideString;
      begin
        stringVal:='';
        if is_constcharnode(p) then
          begin
            SetLength(stringVal,1);
            stringVal[1]:=char(TOrdConstNode(p).Value.uvalue);
            result:=CStringConstNode.createstr(stringVal);
          end
        else if is_constwidecharnode(p) then
          begin
            InitWideString(pWideStringVal);
            ConcatWideStringChar(pWideStringVal, TCompilerWideChar(TOrdConstNode(p).Value.uvalue));
            result:=CStringConstNode.createunistr(pWideStringVal);
          end
        else if p.nodetype=stringconstn then
          result:=TStringConstNode(p.GetCopy)
        else
          begin
            Message(type_e_string_expr_expected);
            stringVal:='';
            result:=CStringConstNode.createstr(stringVal);
          end;
        result.changestringtype(def);
      end;


    function is_constresourcestringnode(p : TNode) : boolean;
      begin
        is_constresourcestringnode:=(p.nodetype=loadn) and
          (TLoadNode(p).symtableentry.typ=constsym) and
          (TConstSym(TLoadNode(p).symtableentry).ConstTyp in [constresourcestring,constwresourcestring]);
      end;


    function is_emptyset(p : TNode):boolean;
      begin
        is_emptyset:=(p.nodetype=setconstn) and
                     (TSetConstNode(p).value_set^=[]);
      end;


    function genconstsymtree(p : TConstSym) : TNode;
      var
        p1  : TNode;
        len : LongInt;
        pc  : pchar;
        value_set : PConstSet;
      begin
        p1:=nil;
        case p.ConstTyp of
          constord :
            begin
              if p.ConstDef=nil then
                InternalError(200403232);
              { no range checking; if it has a fixed type, the necessary value
                truncation was already performed at the declaration time }
              p1:=COrdConstNode.create(p.Value.ValueOrd,p.ConstDef,false);
            end;
          conststring :
            begin
              len:=p.Value.len;
              if not(cs_refcountedstrings in CurrentSettings.LocalSwitches) and (len>255) then
                begin
                  message(parser_e_string_const_too_long);
                  len:=255;
                end;
              GetMem(pc,len+1);
              move(pchar(p.Value.ValuePtr)^,pc^,len);
              pc[len]:=#0;
              p1:=CStringConstNode.createpchar(pc,len,p.ConstDef);
              FreeMem(pc);
            end;
          constwstring :
            p1:=CStringConstNode.createunistr(p.Value.ValueWS);
          constreal :
            begin
              if (sp_generic_para in p.SymOptions) and not (sp_generic_const in p.SymOptions) then
                p1:=CRealConstNode.create(default(BestReal),p.ConstDef)
              else
                p1:=CRealConstNode.create(PBestReal(p.Value.ValuePtr)^,p.ConstDef);
            end;
          constset :
            begin
              if sp_generic_const in p.SymOptions then
                begin
                  new(value_set);
                  value_set^:=PConstSet(p.Value.ValuePtr)^;
                  p1:=CSetConstNode.create(value_set,p.ConstDef);
                end
              else if sp_generic_para in p.SymOptions then
                begin
                  new(value_set);
                  p1:=CSetConstNode.create(value_set,p.ConstDef);
                end
              else
                p1:=CSetConstNode.create(PConstSet(p.Value.ValuePtr),p.ConstDef);
            end;
          constpointer :
            begin
              if sp_generic_para in p.SymOptions then
                p1:=CPointerConstNode.create(default(TConstPtrUInt),p.ConstDef)
              else
                p1:=CPointerConstNode.create(p.Value.ValueOrdPtr,p.ConstDef);
            end;
          constnil :
            p1:=CNilNode.create;
          constguid :
            begin
              if sp_generic_para in p.SymOptions then
                p1:=CGUIDConstNode.create(default(TGUID))
              else
                p1:=CGUIDConstNode.create(PGUID(p.Value.ValuePtr)^);
            end;
          constnone :
            p1:=CNothingNode.create
          else
            InternalError(200205103);
        end;

        if Is_Currency(p.ConstDef) then
          Include(p1.flags, nf_is_currency);

        { transfer generic param flag from symbol to node }
        if sp_generic_para in p.SymOptions then
          include(p1.flags,nf_generic_para);
        genconstsymtree:=p1;
      end;


    function getbooleanvalue(p : TNode) : boolean;
      begin
        if is_constboolnode(p) then
          result:=TOrdConstNode(p).Value<>0
        else
          InternalError(2013111601);
      end;

{*****************************************************************************
                             TREALCONSTNODE
*****************************************************************************}

    { generic code     }
    { overridden by:   }
    {   i386           }
    constructor TRealConstNode.create(v : BestReal;def:TDef);
      begin
         if def.typ<>floatdef then
           InternalError(2002022402);
         inherited create(realconstn);
         typedef:=def;
         SetCurrencyValue(v);
         case TFloatDef(def).FloatType of
           S32Real:
             v:=Single(v);
           S64Real:
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

    constructor TRealConstNode.create_currency_scalar(def:TDef);
      begin
        Create(10000.0,def);
        Include(flags,nf_internal);
        Include(flags,nf_is_currency);
      end;


    function TRealConstNode.CurrencyScaledValue: Int64;
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

    procedure TRealConstNode.SetCurrencyValue(const AValue: BestReal);
      var
        lScaled: BestReal;
        lRaw: Int64;
      begin
        lScaled:=AValue*BestReal(10000);
        FCurrencyRange:=crValid;
        if lScaled=BestReal(QWord($8000000000000000)) then
          begin
            { The parser sees this magnitude before unary minus. }
            FCurrencyRange:=crPositiveLimit;
            lRaw:=Low(Int64);
          end
        else
          begin
            if not Is_Number_Float(lScaled) or
               (lScaled>=BestReal(QWord($8000000000000000))) or
               (lScaled<BestReal(Low(Int64))) then
              begin
                FCurrencyRange:=crOverflow;
                lRaw:=0;
              end
            else
              lRaw:=Round(lScaled);
          end;
        Move(lRaw,value_currency,SizeOf(lRaw));
      end;

    procedure TRealConstNode.SetCurrencyLiteral(const AText: ShortString);
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

    procedure TRealConstNode.NegateValue;
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

    constructor TRealConstNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      var
        i : int64;
      begin
        inherited ppuload(t,ppufile);
        ppufile.GetDeref(TypeDefDeref);
        value_real:=ppufile.GetReal;
        i:=ppufile.GetInt64;
        value_currency:=PCurrency(@i)^;
        FCurrencyRange:=crValid;
        case ppufile.GetByte of
          1: FCurrencyRange:=crPositiveLimit;
          2: FCurrencyRange:=crOverflow;
        end;
        lab_real:=TAsmLabel(ppufile.GetAsmSymbol);
      end;


    procedure TRealConstNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutDeref(TypeDefDeref);
        ppufile.PutReal(value_real);
        ppufile.PutInt64(PInt64(@value_currency)^);
        ppufile.PutByte(Ord(FCurrencyRange));
        ppufile.PutAsmSymbol(lab_real);
      end;


    procedure TRealConstNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        TypeDefDeref.build(typedef);
      end;


    procedure TRealConstNode.derefimpl;
      begin
        inherited derefimpl;
        typedef:=TDef(TypeDefDeref.resolve);
      end;


    function TRealConstNode.dogetcopy : TNode;
      var
         n : TRealConstNode;
      begin
         n:=TRealConstNode(inherited dogetcopy);
         n.typedef:=typedef;
         n.value_real:=value_real;
         n.value_currency:=value_currency;
         n.FCurrencyRange:=FCurrencyRange;
         n.lab_real:=lab_real;
         dogetcopy:=n;
      end;


    function TRealConstNode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=typedef;

        { range checking? }
        if Floating_Point_Range_Check_Error or
           (TFloatDef(resultdef).FloatType in [s64comp,s64currency]) then
          begin
            { use CGMessage so that the resultdef will get set to errordef
              by pass1.typecheckpass_internal if a range error was triggered,
              which in turn will prevent any potential parent type conversion
              node from creating a new realconstnode with this exact same value
              and hence trigger the same error again }
            case TFloatDef(resultdef).FloatType of
              S32Real :
                begin
                  if Single(value_real)=MathInf.Value then
                    CGMessage(parser_e_range_check_error);
                end;
              S64Real:
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
                  if (value_real>BestReal(High(Int64))) or
                     (value_real<BestReal(Low(Int64))) then
                    CGMessage(parser_e_range_check_error)
                end;
            end;
          end;
      end;


    function TRealConstNode.pass_1 : TNode;
      begin
         result:=nil;
         expectloc:=LOC_CREFERENCE;
      end;


    function TRealConstNode.simplify(forinline : boolean) : TNode;
      begin
        result:=nil;
        if (Frac(value_real)<>0.0) and Is_Currency(resultdef) and not (nf_is_currency in flags) then
          begin
            { Unfortunately we can't safely store unscaled Currency values with
              fractional components in a cross-platform way, so scale it here
              so its 4 decimal places are preserved }
            value_real:=value_real*BestReal(10000.0);
            Include(flags,nf_is_currency);
            Include(flags,nf_internal);
          end;
      end;


    function TRealConstNode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          { this should be always true }
          (TRealConstNode(p).typedef.typ=floatdef) and (typedef.typ=floatdef) and
          (TFloatDef(typedef).FloatType = TFloatDef(TRealConstNode(p).typedef).FloatType) and
          (
           (
            (TFloatDef(typedef).FloatType=s64currency) and
            (CurrencyScaledValue=TRealConstNode(p).CurrencyScaledValue)
           )
           or
           (
            (TFloatDef(typedef).FloatType<>s64currency) and
            (value_real=TRealConstNode(p).value_real) and
            (
              { Make sure 0.0 and -0.0 are not equated unless fastmath is enabled }
              (cs_opt_fastmath in CurrentSettings.OptimizerSwitches) or
              not (
                (
                  IsPosZero(value_real) and
                  IsNegZero(TRealConstNode(p).value_real)
                ) or
                (
                  IsNegZero(value_real) and
                  IsPosZero(TRealConstNode(p).value_real)
                )
              )
            ) and
            { floating point compares for non-numbers give strange results usually }
            Is_Number_Float(value_real) and
            Is_Number_Float(TRealConstNode(p).value_real)
           )
          );
      end;


    procedure TRealConstNode.printnodedata(var t: text);
      begin
        inherited printnodedata(t);
        write(t,PrintNodeIndention,'value = ',RealToStr(value_real));
        if Is_Currency(resultdef) then
          WriteLn(t,', value_currency = ',value_currency)
        else
          WriteLn(t);
      end;

    function TRealConstNode.emit_data(tcb:TTAITypedConstBuilder):sizeint;
      begin
        case TFloatDef(typedef).FloatType of
          S32Real:
            tcb.emit_tai(TAIRealConst.create_s32real(Single(value_real)),typedef);
          S64Real:
            tcb.emit_tai(TAIRealConst.create_s64real(Double(value_real)),typedef);
          s80real:
            tcb.emit_tai(TAIRealConst.create_s80real(value_real,S80FloatType.Size),typedef);
          sc80real:
            tcb.emit_tai(TAIRealConst.create_s80real(value_real,SC80FloatType.Size),typedef);
          s64comp:
            { the round is necessary for native compilers where comp isn't a float }
            tcb.emit_tai(TAIRealConst.create_s64compreal(Round(value_real)),typedef);
          s64currency:
            { Lowered Currency nodes already contain the integer payload. }
            tcb.emit_tai(TAIRealConst.create_s64compreal(Round(value_real)),typedef);
        end;
        result:=resultdef.Size;
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TRealConstNode.XMLPrintNodeData(var T: Text);
      begin
        inherited XMLPrintNodeData(T);
        WriteLn(T, PrintNodeIndention, '<value>', RealToStr(value_real), '</value>');
      end;
{$endif DEBUG_NODE_XML}

{*****************************************************************************
                              TORDCONSTNODE
*****************************************************************************}

    constructor TOrdConstNode.create(const v : TConstExprInt;def:TDef;_rangecheck : boolean);

      begin
         inherited create(ordconstn);
         value:=v;
         typedef:=def;
         rangecheck := _rangecheck;
      end;


    constructor TOrdConstNode.create_currency_scalar(def:TDef);
      begin
        Create(10000,def,false);
        Include(flags,nf_internal);
        Include(flags,nf_is_currency);
      end;


    constructor TOrdConstNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.GetDeref(TypeDefDeref);
        value:=ppufile.GetExprInt;
        { normally, the value is already compiled, so we don't need
          to do once again a range check
        }
        rangecheck := false;
      end;


    procedure TOrdConstNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutDeref(TypeDefDeref);
        ppufile.PutExprInt(value);
      end;


    procedure TOrdConstNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        TypeDefDeref.build(typedef);
      end;


    procedure TOrdConstNode.derefimpl;
      begin
        inherited derefimpl;
        typedef:=TDef(TypeDefDeref.resolve);
      end;


    function TOrdConstNode.dogetcopy : TNode;

      var
         n : TOrdConstNode;

      begin
         n:=TOrdConstNode(inherited dogetcopy);
         n.Value:=value;
         n.typedef := typedef;
         dogetcopy:=n;
      end;

    function TOrdConstNode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=typedef;
        { only do range checking when explicitly asked for it
          and if the type can be range checked, see tests/tbs/tb0539.pas }
        if (resultdef.typ in [orddef,enumdef]) and not(nf_generic_para in flags) then
          AdaptRange(resultdef,value,nf_internal in flags,not rangecheck,rangecheck)
      end;

    function TOrdConstNode.pass_1 : TNode;
      begin
         result:=nil;
         expectloc:=LOC_CONSTANT;
      end;

    function TOrdConstNode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (value = TOrdConstNode(p).Value) and
          Equal_Defs(typedef,TOrdConstNode(p).typedef);
      end;


    procedure TOrdConstNode.printnodedata(var t: text);
      begin
        inherited printnodedata(t);
        WriteLn(t,PrintNodeIndention,'typedef = "',typedef.GetTypeName,'"');
        WriteLn(t,PrintNodeIndention,'value = ',ToStr(value));
      end;

    function TOrdConstNode.emit_data(tcb:TTAITypedConstBuilder):sizeint;
      begin
        tcb.emit_ord_const(value,resultdef);
        result:=resultdef.Size;
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
        WriteLn(T, PrintNodeIndention, '<value>', ToStr(value), '</value>');
      end;
{$endif DEBUG_NODE_XML}

{*****************************************************************************
                            TPOINTERCONSTNODE
*****************************************************************************}

    constructor TPointerConstNode.create(v : TConstPtrUInt;def:TDef);
      begin
        inherited create(pointerconstn);
        value:=v;
        typedef:=def;
      end;


    constructor TPointerConstNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.GetDeref(TypeDefDeref);
        value:=ppufile.GetPtrUInt;
      end;


    procedure TPointerConstNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutDeref(TypeDefDeref);
        ppufile.PutPtrUInt(value);
      end;


    procedure TPointerConstNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        TypeDefDeref.build(typedef);
      end;


    procedure TPointerConstNode.derefimpl;
      begin
        inherited derefimpl;
        typedef:=TDef(TypeDefDeref.resolve);
      end;


    function TPointerConstNode.dogetcopy : TNode;
      var
         n : TPointerConstNode;
      begin
        n:=TPointerConstNode(inherited dogetcopy);
        n.Value:=value;
        n.typedef := typedef;
        dogetcopy:=n;
      end;


    function TPointerConstNode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=typedef;
        if Is_VoidPointer(resultdef) and (value=0) then
          result:=CNilNode.create;
      end;


    function TPointerConstNode.pass_1 : TNode;
      begin
        result:=nil;
        expectloc:=LOC_CONSTANT;
      end;


    function TPointerConstNode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (value = TPointerConstNode(p).Value);
      end;


    procedure TPointerConstNode.printnodedata(var t : text);
      begin
        inherited printnodedata(t);
        WriteLn(t,PrintNodeIndention,'value = $',HexStr(PUint(value),sizeof(PUint)*2));
      end;

    function TPointerConstNode.emit_data(tcb: TTAITypedConstBuilder): sizeint;
      begin
        if TPointerDef(resultdef).Compatible_With_PointerDef_Size(TPointerDef(VoidPointerType)) then
          tcb.emit_tai(TAIConst.Create_int_dataptr(value),VoidPointerType)
        else
          tcb.emit_tai(TAIConst.Create_int_codeptr(value),VoidCodePointerType);
        result:=resultdef.Size;
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TPointerConstNode.XMLPrintNodeData(var T: Text);
      begin
        inherited XMLPrintNodeData(T);
        WriteLn(T, PrintNodeIndention, '<value>$', HexStr(PUint(value),sizeof(PUint)*2), '</value>');
      end;
{$endif DEBUG_NODE_XML}

{*****************************************************************************
                             TSTRINGCONSTNODE
*****************************************************************************}

    constructor TStringConstNode.createstr(const s : string);
      var
         l : LongInt;
      begin
         inherited create(stringconstn);
         l:=length(s);
         len:=l;
         { stringdup write even past a #0 }
         SetLength(valueas,l+1);
         valueas[l]:=#0;
         if l>0 then
           move(s[1],valueas[0],l);
         lab_str:=nil;
         cst_type:=cst_conststring;
      end;


    constructor TStringConstNode.createunistr(w : TCompilerWideString);
      begin
         inherited create(stringconstn);
         len:=GetLengthWideString(w);
         InitWideString(ValueWS);
         CopyWideString(w,ValueWS);
         lab_str:=nil;
         cst_type:=cst_unicodestring;
      end;


    constructor TStringConstNode.createpchar(s: pchar; l: LongInt; def: TDef);
      begin
         inherited create(stringconstn);
         len:=l;
         SetLength(valueas,l+1);
         valueas[l]:=#0;
         if l>0 then
           move(s[0],valueas[0],l);
         if Assigned(def) and
            Is_AnsiString(def) then
           begin
             cst_type:=cst_ansistring;
             astringdef:=def;
           end
         else
           cst_type:=cst_conststring;
         lab_str:=nil;
      end;


    destructor TStringConstNode.Destroy;
      begin
        if cst_type in [cst_widestring,cst_unicodestring] then
          DoneWideString(ValueWS)
        else
          valueas:=nil;
        inherited Destroy;
      end;


    constructor TStringConstNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      var
        i : LongInt;
      begin
        inherited ppuload(t,ppufile);
        cst_type:=TConstStringType(ppufile.GetByte);
        len:=ppufile.GetLongInt;
        if cst_type in [cst_widestring,cst_unicodestring] then
          begin
            InitWideString(ValueWS);
            SetLengthWideString(ValueWS,len);
            { don't use getdata, because the compilerwidechars may have to
              be byteswapped
            }
            for i:=0 to ValueWS.len-1 do
              ValueWS.data[i]:=ppufile.GetWord;
          end
        else
          begin
            SetLength(valueas,len+1);
            valueas[len]:=#0;
            if len>0 then
              ppufile.GetData(valueas[0],len);
          end;
        lab_str:=TAsmLabel(ppufile.GetAsmSymbol);
        if cst_type=cst_ansistring then
          ppufile.GetDeref(astringdefderef);
      end;


    procedure TStringConstNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutByte(byte(cst_type));
        ppufile.PutLongInt(len);
        if len>0 then
          if cst_type in [cst_widestring,cst_unicodestring] then
            ppufile.PutData(ValueWS.data[0],len*sizeof(TCompilerWideChar))
          else
            ppufile.PutData(valueas[0],len);
        ppufile.PutAsmSymbol(lab_str);
        if cst_type=cst_ansistring then
          ppufile.PutDeref(astringdefderef);
      end;


    procedure TStringConstNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        if cst_type=cst_ansistring then
          astringdefderef.build(astringdef);
      end;


    procedure TStringConstNode.derefimpl;
      begin
        inherited derefimpl;
        if cst_type=cst_ansistring then
          astringdef:=TDef(astringdefderef.resolve);
      end;


    function TStringConstNode.dogetcopy : TNode;

      var
         n : TStringConstNode;

      begin
         n:=TStringConstNode(inherited dogetcopy);
         n.cst_type:=cst_type;
         n.len:=len;
         n.lab_str:=lab_str;
         if cst_type in [cst_widestring,cst_unicodestring] then
           begin
             InitWideString(n.ValueWS);
             CopyWideString(ValueWS,n.ValueWS);
           end
         else
           begin
           SetLength(n.valueas,len+1);
           n.valueas[len]:=#0;
           if len>0 then
             move(valueas[0],n.valueas[0],len);
           end;
         n.astringdef:=astringdef;
         dogetcopy:=n;
      end;


    function TStringConstNode.pass_typecheck:TNode;
      begin
        result:=nil;
        case cst_type of
          cst_conststring :
            begin
              { handle and store as array[0..len-1] of char }
              resultdef:=CArrayDef.create(0,len-1,S32IntType);
              TArrayDef(resultdef).ElementDef:=CAnsiCharType;
              include(TArrayDef(resultdef).ArrayOptions,ado_IsConstString);
            end;
          cst_shortstring :
            resultdef:=CShortStringType;
          cst_ansistring :
            if not Assigned(astringdef) then
              resultdef:=GetAnsiStringDef
            else
              resultdef:=astringdef;
          cst_unicodestring :
            resultdef:=CUnicodeStringType;
          cst_widestring :
            resultdef:=CWideStringType;
          cst_longstring :
            resultdef:=CLongStringType;
        end;
      end;


    function TStringConstNode.pass_1 : TNode;
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


    function TStringConstNode.getpcharcopy : pchar;
      var
         pc : pchar;
      begin
         pc:=nil;
         GetMem(pc,len+1);
         if pc=nil then
           Message(general_f_no_memory_left);
         pc[len]:=#0;
         if len>0 then
           move(valueas[0],pc^,len);
         getpcharcopy:=pc;
      end;

    function TStringConstNode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (len = TStringConstNode(p).len) and
          (lab_str = TStringConstNode(p).lab_str) and
          { This is enough as soon as labels are allocated, otherwise }
          { fall back to content compare.                             }
          (Assigned(lab_str) or
            (cst_type = TStringConstNode(p).cst_type) and
            (fullcompare(TStringConstNode(p)) = 0))
          ;
      end;


    procedure TStringConstNode.changestringtype(def:TDef);
      const
        st2cst : array[TStringType] of TConstStringType = (
          cst_shortstring,cst_longstring,cst_ansistring,cst_widestring,cst_unicodestring);
      var
        pw : TCompilerWideString;
        pc : pchar;
        cp1 : TStringEncoding;
        cp2 : TStringEncoding;
        l,l2 : LongInt;
      begin
        if def.typ<>stringdef then
          InternalError(200510011);
        { convert ascii 2 unicode }
        if (TStringDef(def).StringType in [st_widestring,st_unicodestring]) and
           not(cst_type in [cst_widestring,cst_unicodestring]) then
          begin
            InitWideString(ValueWS);
            ASCII2Unicode(asconstpchar,len,CurrentSettings.SourceCodePage,ValueWS);
          end
        else
          { convert unicode 2 ascii }
          if (cst_type in [cst_widestring,cst_unicodestring]) and
            not(TStringDef(def).StringType in [st_widestring,st_unicodestring]) then
            begin
              cp1:=TStringDef(def).encoding;
              if (cp1=Globals.CP_NONE) or (cp1=0) then
                cp1:=CurrentSettings.SourceCodePage;
              if (cp1=CP_UTF8) then
                begin
                  l2:=len;
                  l:=UnicodeToUtf8(nil,0,ValueWS.AsConstPUnicodeChar,l2);
                  SetLength(valueas,l+1);
                  valueas[l]:=#0;
                  if l>0 then
                    UnicodeToUtf8(asconstpchar,l,ValueWS.AsConstPUnicodeChar,l2);
                  len:=l-1;
                  DoneWideString(ValueWS);
                end
              else
                begin
                  SetLength(valueas,GetLengthWideString(ValueWS)+1);
                  len:=Length(valueas)-1;
                  Unicode2ASCII(ValueWS,asconstpchar,cp1);
                  DoneWideString(ValueWS);
                end;
            end
        else
          if (TStringDef(def).StringType = st_ansistring) and
             not(cst_type in [cst_widestring,cst_unicodestring]) then
            begin
              cp1:=TStringDef(def).encoding;
              if cp1=0 then
                cp1:=CurrentSettings.SourceCodePage;
              if (cst_type = cst_ansistring) then
                begin
                  cp2:=TStringDef(resultdef).encoding;
                  if cp2=0 then
                    cp2:=CurrentSettings.SourceCodePage;
                end
              else if (cst_type in [cst_shortstring,cst_conststring,cst_longstring]) then
                cp2:=CurrentSettings.SourceCodePage
              else
                InternalError(2013112916);
              { don't change string if codepages are equal or string length is 0 }
              if (cp1<>cp2) and (len>0) then
                begin
                  if CPAvailable(cp1) and CPAvailable(cp2) then
                    ChangeCodePage(asconstpchar,len,cp2,asconstpchar,cp1)
                  else if (cp1 <> Globals.CP_NONE) and (cp2 <> Globals.CP_NONE) then
                    begin
                      { if source encoding is UTF8 convert using UTF8->UTF16->destination encoding }
                      if (cp2=CP_UTF8) then
                        begin
                          if not CPAvailable(cp1) then
                            begin
                              Message1(option_code_page_not_available,IntToStr(cp1));
                              exit;
                            end;
                          InitWideString(pw);
                          SetLengthWideString(pw,len);
                          { returns room for terminating 0 }
                          if len>0 then
                            l:=Utf8ToUnicode(pw.AsConstPUnicodeChar,len,asconstpchar,len)
                          else
                            l:=1;
                          if (l<>GetLengthWideString(pw)) then
                            begin
                              SetLengthWideString(pw,l);
                              SetLength(valueas,l);
                              valueas[l-1]:=#0;
                            end;
                          Unicode2ASCII(pw,valueas,cp1);
                          len:=l-1;
                          DoneWideString(pw);
                        end
                      else
                      { if destination encoding is UTF8 convert using source encoding->UTF16->UTF8 }
                      if (cp1=CP_UTF8) then
                        begin
                          if not CPAvailable(cp2) then
                            begin
                              Message1(option_code_page_not_available,IntToStr(cp2));
                              exit;
                            end;
                          InitWideString(pw);
                          SetLengthWideString(pw,len);
                          ASCII2Unicode(asconstpchar,len,cp2,pw);
                          { returns room for terminating 0 }
                          l:=UnicodeToUtf8(nil,0,pw.AsConstPUnicodeChar,len);
                          if l<>len then
                            begin
                            SetLength(valueas,l);
                            valueas[l-1]:=#0;
                            end;
                          UnicodeToUtf8(asconstpchar,l,pw.AsConstPUnicodeChar,len);
                          len:=l-1;
                          DoneWideString(pw);
                        end
                      else
                        begin
                          { output error message that encoding is not available for the compiler }
                          if not CPAvailable(cp1) then
                            Message1(option_code_page_not_available,IntToStr(cp1));
                          if not CPAvailable(cp2) then
                            Message1(option_code_page_not_available,IntToStr(cp2));
                        end;
                    end;
                end;
            end;
        cst_type:=st2cst[TStringDef(def).StringType];
        resultdef:=def;
      end;

    function TStringConstNode.fullcompare(p: TStringConstNode): LongInt;
      begin
        if cst_type<>p.cst_type then
          InternalError(2009121701);
        if cst_type in [cst_widestring,cst_unicodestring] then
          result:=CompareWideStrings(ValueWS,p.ValueWS)
        else
          result:=CompareAnsiStrings(asconstpchar,p.asconstpchar,len,p.len);
      end;

    function TStringConstNode.emit_data(tcb:TTAITypedConstBuilder):sizeint;
      var
        ss : shortstring;
        labofs : TAsmLabOfs;
        winlikewidestring : boolean;
      begin
        case TStringDef(resultdef).StringType of
          st_shortstring:
            begin
              SetLength(ss,len);
              if len>0 then
                move(valueas[0],ss[1],len);
              tcb.emit_shortstring_const(ss);
              result:=len+1;
            end;
          st_longstring:
            InternalError(2019070801);
          st_ansistring:
            begin
              labofs:=tcb.emit_ansistring_const(CurrentAsmData.asmlists[al_typedconsts],asconstpchar,len,TStringDef(resultdef).encoding);
              tcb.emit_string_offset(labofs,len,TStringDef(resultdef).StringType,false,CharPointerType);
              result:=VoidPointerType.Size;
            end;
          st_widestring,
          st_unicodestring:
            begin
              winlikewidestring:=(cst_type=cst_widestring) and (tf_winlikewidestring in TargetInfo.flags);
              labofs:=tcb.emit_unicodestring_const(CurrentAsmData.asmlists[al_typedconsts],ValueWS,TStringDef(resultdef).encoding,winlikewidestring);
              tcb.emit_string_offset(labofs,len,TStringDef(resultdef).StringType,false,WideCharPointerType);
              result:=VoidPointerType.Size;
            end;
        end;
      end;

    function TStringConstNode.asrawbytestring: rawbytestring;
    begin
      Result:='';
      if Length(valueas)>0 then
        Result:=pchar(@valueas[0]);
    end;

    var
      cEmptyString : ansichar = #0;

    function TStringConstNode.asconstpchar: pchar;
    begin
      if length(valueas)>0 then
        Result:=@valueas[0]
      else
        Result:=@cEmptyString;
    end;

    class function TStringConstNode.emptydynstrnil: boolean;
      begin
        result:=true;
      end;

      procedure TStringConstNode.printnodedata(var T: Text);
      var
        u : unicodestring;

      begin
        inherited printnodedata(t);
        if length(valueas)>0 then
          WriteLn(t,PrintNodeIndention,'value = "',PAnsiChar(@valueas[0]),'"')
        else if Assigned(ValueWS) and (ValueWS.len>0) then
          begin
          SetLength(u,ValueWS.len);
          move(ValueWS.data[0],u[1],ValueWS.len*sizeof(unicodechar));
          WriteLn(t,PrintNodeIndention,'value = "',u,'"');
          end
        else
          WriteLn(t,PrintNodeIndention,'value = ""');
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TStringConstNode.XMLPrintNodeData(var T: Text);
      var
        OutputStr: AnsiString;
      begin
        inherited XMLPrintNodeData(T);
        Write(T, PrintNodeIndention, '<stringtype>');
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
        WriteLn(T, PrintNodeIndention, '<length>', len, '</length>');

        if len = 0 then
          begin
            WriteLn(T, PrintNodeIndention, '<value />');
            Exit;
          end;

        case cst_type of
        cst_widestring, cst_unicodestring:
          begin
            { value_str is of type PCompilerWideString }
            SetLength(OutputStr, len);
            UnicodeToUtf8(PChar(OutputStr), PUnicodeChar(ValueWS.data), len + 1); { +1 for the null terminator }
          end;
        else
          OutputStr := PAnsiChar(@valueas[0]);
          SetLength(OutputStr, len);
        end;

        WriteLn(T, PrintNodeIndention, '<value>', SanitiseXMLString(OutputStr), '</value>');
      end;
{$endif DEBUG_NODE_XML}

{*****************************************************************************
                             TSETCONSTNODE
*****************************************************************************}

    constructor TSetConstNode.create(s : PConstSet;def:TDef);

      begin
         inherited create(setconstn,nil);
         typedef:=def;
         if Assigned(s) then
           begin
              new(value_set);
              value_set^:=s^;
           end
         else
           value_set:=nil;
      end;


    destructor TSetConstNode.Destroy;
      begin
        if Assigned(value_set) then
         dispose(value_set);
        inherited Destroy;
      end;


    constructor TSetConstNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.GetDeref(TypeDefDeref);
        new(value_set);
        ppufile.GetSet(TPPUSet32(value_set^));
      end;


    procedure TSetConstNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutDeref(TypeDefDeref);
        ppufile.PutSet(TPPUSet32(value_set^));
      end;


    procedure TSetConstNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        TypeDefDeref.build(typedef);
      end;


    procedure TSetConstNode.derefimpl;
      begin
        inherited derefimpl;
        typedef:=TDef(TypeDefDeref.resolve);
      end;

    type
       TSetBytes = array[0..31] of byte;
       PSetBytes = ^TSetBytes;

    procedure TSetConstNode.adjustforsetbase;
      var
        i, diff: LongInt;
      begin
        { Internally, the compiler stores all sets with setbase 0, so we have }
        { to convert the set to its actual format in case setbase<>0 when     }
        { writing it out                                                      }
        if (TSetDef(resultdef).SetBase<>0) then
          begin
            if (TSetDef(resultdef).SetBase and 7)<>0 then
              InternalError(2007091501);
            diff:=TSetDef(resultdef).SetBase div 8;
            { This is endian-neutral in the new set format: in both cases, }
            { the first byte contains the first elements of the set.       }
            { Since the compiler/base rtl cannot contain packed sets before }
            { they work for big endian, it's no problem that the code below }
            { is wrong for the old big endian set format (setbase cannot be }
            { <>0 with non-packed sets).                                    }
            for i:=0 to TSetDef(resultdef).Size-1 do
              begin
                PSetBytes(value_set)^[i]:=PSetBytes(value_set)^[i+diff];
                PSetBytes(value_set)^[i+diff]:=0;
              end;
          end;
      end;


    function TSetConstNode.dogetcopy : TNode;
      var
         n : TSetConstNode;
      begin
         n:=TSetConstNode(inherited dogetcopy);
         if Assigned(value_set) then
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


    function TSetConstNode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=typedef;
      end;


    function TSetConstNode.pass_1 : TNode;
      begin
         result:=nil;
         if Is_SmallSet(resultdef) then
          expectloc:=LOC_CONSTANT
         else
          expectloc:=LOC_CREFERENCE;
      end;


    function TSetConstNode.docompare(p: TNode): boolean;
      begin
        docompare:=(inherited docompare(p)) and
                   (value_set^=TSetConstNode(p).value_set^);
      end;


    function TSetConstNode.elements : AInt;
      var
        i : LongInt;
      begin
        result:=0;
        if not(Assigned(value_set)) then
          exit;
        for i:=0 to TSetDef(resultdef).Size-1 do
          result:=result+ PopCnt(PSetBytes(value_set)^[i]);
      end;


    function TSetConstNode.low: AInt;
      var
        i: ASizeInt;
      begin
        result:=0;
        if not(Assigned(value_set)) then
          exit;
        i:=0;
        while i<=TSetDef(resultdef).SetMax do
          begin
            if i in value_set^ then
              begin
                result:=i;
                exit;
              end;
            inc(i);
          end;
      end;


    function TSetConstNode.high: AInt;
      var
        i: ASizeInt;
      begin
        result:=0;
        if not(Assigned(value_set)) then
          exit;
        i:=TSetDef(resultdef).SetMax;
        while i>=TSetDef(resultdef).SetBase do
          begin
            if i in value_set^ then
              begin
                result:=i;
                exit;
              end;
            dec(i);
          end;
      end;


    function TSetConstNode.emit_data(tcb:TTAITypedConstBuilder):sizeint;
      type
        TSetBytes=array[0..31] of byte;
        PSetBytes=^TSetBytes;
      var
        setval : aint;
        i : sizeint;
      begin
        if Is_SmallSet(resultdef) then
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
                setval:=aint(Reverse_LongWord(Pcardinal(value_set)^));
              end;
            if (TargetInfo.endian=endian_big) then
              setval:=setval shr (32-resultdef.Size*8);
            case resultdef.Size of
              1:
                tcb.emit_ord_const(byte(setval),U8IntType);
              2:
                tcb.emit_ord_const(word(setval),U16IntType);
              4:
                tcb.emit_ord_const(LongWord(setval),U32IntType);
              8:
                tcb.emit_ord_const(qword(setval),U64IntType);
              else
                InternalError(2019070802);
            end;
          end
        else
          begin
            if (SourceInfo.endian=TargetInfo.endian) then
              for i:=0 to resultdef.Size-1 do
                tcb.emit_tai(TAIConst.create_8bit(PSetBytes(value_set)^[i]),U8IntType)
            else
              for i:=0 to resultdef.Size-1 do
                tcb.emit_tai(TAIConst.create_8bit(Reverse_Byte(PSetBytes(value_set)^[i])),U8IntType);
          end;
        result:=resultdef.Size;
      end;


{*****************************************************************************
                               TNILNODE
*****************************************************************************}

    constructor TNilNode.create;

      begin
        inherited create(niln);
      end;

    function TNilNode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=VoidPointerType;
      end;

    function TNilNode.emit_data(tcb: TTAITypedConstBuilder): sizeint;
      begin
        if TPointerDef(resultdef).Compatible_With_PointerDef_Size(TPointerDef(VoidPointerType)) then
          tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType)
        else
          tcb.emit_tai(TAIConst.Create_nil_codeptr,VoidCodePointerType);
        result:=resultdef.Size;
      end;

    function TNilNode.pass_1 : TNode;
      begin
        result:=nil;
        expectloc:=LOC_CONSTANT;
      end;

{*****************************************************************************
                            TGUIDCONSTNODE
*****************************************************************************}

    constructor TGUIDConstNode.create(const g:TGUID);

      begin
         inherited create(guidconstn);
         value:=g;
      end;

    constructor TGUIDConstNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.GetGUID(value);
      end;


    procedure TGUIDConstNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutGUID(value);
      end;


    function TGUIDConstNode.dogetcopy : TNode;
      var
         n : TGUIDConstNode;
      begin
         n:=TGUIDConstNode(inherited dogetcopy);
         n.Value:=value;
         n.lab_set:=lab_set;
         dogetcopy:=n;
      end;


    function TGUIDConstNode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=Rec_TGUID;
      end;


    function TGUIDConstNode.pass_1 : TNode;
      begin
         result:=nil;
         expectloc:=LOC_CREFERENCE;
      end;


    function TGUIDConstNode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (GUID2String(value) = GUID2String(TGUIDConstNode(p).Value));
      end;

    function TGUIDConstNode.emit_data(tcb: TTAITypedConstBuilder): sizeint;
      begin
        tcb.emit_guid_const(value);
        result:=resultdef.Size;
      end;

end.
