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
         function Emit_Data(ABuilder:TTAITypedConstBuilder):SizeInt;virtual;abstract;
       end;

       TRealConstNode = class(TConstNode)
        private
          FCurrencyRange: (crValid, crPositiveLimit, crOverflow);
        public
          TypeDef : TDef;
          TypeDefDeref : TDeref;
          ValueReal : BestReal;
          ValueCurrency : Currency;
          RealLabel : TAsmLabel;
          constructor Create(AValue : BestReal;ADef:TDef);virtual;
          constructor Create_Currency_Scalar(ADef:TDef);
          function CurrencyScaledValue: Int64;
          procedure SetCurrencyValue(const AValue: BestReal);
          procedure SetCurrencyLiteral(const AText: ShortString);
          procedure NegateValue;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          function DoGetCopy : TNode;override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function Simplify(AForInline : Boolean) : TNode;override;
          function DoCompare(ANode: TNode) : Boolean; override;
          procedure PrintNodeData(var AText:text);override;
          function Emit_Data(ABuilder:TTAITypedConstBuilder):SizeInt; override;
       end;
       TRealConstNodeClass = class of TRealConstNode;

       TOrdConstNode = class(TConstNode)
          TypeDef : TDef;
          TypeDefDeref : TDeref;
          Value : TConstExprInt;
          RangeCheck : Boolean;
          { create an ordinal constant node of the specified type and value.
            ARangeCheck determines if the value of the ordinal should be checked
            against the ranges of the type definition.
          }
          constructor Create(const AValue : TConstExprInt;ADef:TDef; ARangeCheck : Boolean);virtual;
          constructor Create_Currency_Scalar(ADef:TDef);
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          function DoGetCopy : TNode;override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function DoCompare(ANode: TNode) : Boolean; override;
          procedure PrintNodeData(var AText:text);override;
          function Emit_Data(ABuilder:TTAITypedConstBuilder):SizeInt; override;
       end;
       TOrdConstNodeClass = class of TOrdConstNode;

       TPointerConstNode = class(TConstNode)
          TypeDef : TDef;
          TypeDefDeref : TDeref;
          Value   : TConstPtrUInt;
          constructor Create(AValue : TConstPtrUInt;ADef:TDef);virtual;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          function DoGetCopy : TNode;override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function DoCompare(ANode: TNode) : Boolean; override;
          procedure PrintNodeData(var AText : text); override;
          function Emit_Data(ABuilder:TTAITypedConstBuilder):SizeInt; override;
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
          ValueAS : TAnsiCharDynArray;
          ValueWS : TCompilerWideString;
          Len     : LongInt;
          StringLabel : TAsmLabel;
          AStringDef : TDef;
          AStringDefDeref : TDeref;
          ConstStringType : TConstStringType;
          constructor CreateStr(const AString : string);virtual;
          constructor CreatePChar(AChars: PChar; ALength: LongInt; ADef: TDef);virtual;
          constructor CreateUniStr(AWideString : TCompilerWideString);virtual;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          destructor Destroy;override;
          function DoGetCopy : TNode;override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function GetPCharCopy : PChar;
          function DoCompare(ANode: TNode) : Boolean; override;
          procedure ChangeStringType(ADef:TDef);
          function FullCompare(ANode: TStringConstNode): LongInt;
          function Emit_Data(ABuilder:TTAITypedConstBuilder):SizeInt; override;
          function AsRawByteString: RawByteString;
          function AsConstPChar : PChar; inline;
          { returns whether this platform uses the nil pointer to represent
            empty dynamic strings }
          class function EmptyDynStrNil: Boolean; virtual;
          procedure PrintNodeData(var AText: Text); override;
       end;
       TStringConstNodeClass = class of TStringConstNode;

       TSetConstNode = class(TUnaryNode)
          TypeDef : TDef;
          TypeDefDeref : TDeref;
          ValueSet : PConstSet;
          DataLabel : TAsmSymbol;
          constructor Create(ASet : PConstSet;ADef:TDef);virtual;
          destructor Destroy;override;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          procedure AdjustForSetBase;
          function DoGetCopy : TNode;override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function DoCompare(ANode: TNode) : Boolean; override;
          function Elements : AInt;
          function Low : AInt;
          function High : AInt;
          function Emit_Data(ABuilder:TTAITypedConstBuilder):SizeInt;
       end;
       TSetConstNodeClass = class of TSetConstNode;

       TNilNode = class(TConstNode)
          constructor Create;virtual;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function Emit_Data(ABuilder:TTAITypedConstBuilder):SizeInt; override;
       end;
       TNilNodeClass = class of TNilNode;

       TGUIDConstNode = class(TConstNode)
          Value : TGUID;
          DataLabel : TAsmSymbol;
          constructor Create(const AGUID:TGUID);virtual;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          function DoGetCopy : TNode;override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function DoCompare(ANode: TNode) : Boolean; override;
          function Emit_Data(ABuilder:TTAITypedConstBuilder):SizeInt; override;
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
    function GenIntConstNode(const AValue : TConstExprInt) : TOrdConstNode; overload;
    { Creates tordconstnode with the preferredinttype type or a bigger type which can hold v }
    function GenIntConstNode(const AValue : TConstExprInt; APreferredIntType : TDef) : TOrdConstNode; overload;
    function GenEnumNode(AEnumSym : TEnumSym) : TOrdConstNode;

    { some helper routines }
    function Get_Ordinal_Value(ANode : TNode) : TConstExprInt;
    function Get_String_Value(ANode : TNode; ADef: TStringDef) : TStringConstNode;
    function Is_ConstResourceStringNode(ANode : TNode) : Boolean;
    function Is_EmptySet(ANode : TNode):Boolean;
    function GenConstSymTree(ASym : TConstSym) : TNode;

    function GetBooleanValue(ANode : TNode) : Boolean;

implementation

    uses
      CUtils,utcurrencyparse,
      Verbose,Systems,SysUtils,PPU,
      defcmp,defutil,ProcInfo,
      AAsmData,aasmtai,
      cgbase,
      nld,nbas,ncnv,nmat;

    function GenIntConstNode(const AValue : TConstExprInt) : TOrdConstNode;
      var
        lType : TDef;
      begin
         Int_To_Type(AValue,lType);
         GenIntConstNode:=COrdConstNode.Create(AValue,lType,true);
      end;


    function GenIntConstNode(const AValue : TConstExprInt; APreferredIntType : TDef) : TOrdConstNode;
      var
        lType : TDef;
      begin
        Int_To_Type(AValue,lType);
        if lType.Size<APreferredIntType.Size then
          lType:=APreferredIntType;
        Result:=COrdConstNode.Create(AValue,lType,true);
      end;


    function GenEnumNode(AEnumSym : TEnumSym) : TOrdConstNode;
      var
        lType : TDef;
      begin
         lType:=AEnumSym.definition;
         GenEnumNode:=COrdConstNode.Create(Int64(AEnumSym.Value),lType,true);
      end;


    function Get_Ordinal_Value(ANode : TNode) : TConstExprInt;
      begin
        Get_Ordinal_Value:=0;
        if Is_ConstNode(ANode) then
          begin
            if ANode.NodeType=ordconstn then
              Get_Ordinal_Value:=TOrdConstNode(ANode).Value
            else
              Message(type_e_ordinal_expr_expected);
          end
        else
          Message(type_e_constant_expr_expected);
      end;

    function Get_String_Value(ANode: TNode; ADef: TStringDef): TStringConstNode;
      var
        lStringValue: string;
        lWideStringValue: TCompilerWideString;
      begin
        lStringValue:='';
        if Is_ConstCharNode(ANode) then
          begin
            SetLength(lStringValue,1);
            lStringValue[1]:=char(TOrdConstNode(ANode).Value.uvalue);
            Result:=CStringConstNode.CreateStr(lStringValue);
          end
        else if Is_ConstWideCharNode(ANode) then
          begin
            InitWideString(lWideStringValue);
            ConcatWideStringChar(lWideStringValue, TCompilerWideChar(TOrdConstNode(ANode).Value.uvalue));
            Result:=CStringConstNode.CreateUniStr(lWideStringValue);
          end
        else if ANode.NodeType=stringconstn then
          Result:=TStringConstNode(ANode.GetCopy)
        else
          begin
            Message(type_e_string_expr_expected);
            lStringValue:='';
            Result:=CStringConstNode.CreateStr(lStringValue);
          end;
        Result.ChangeStringType(ADef);
      end;


    function Is_ConstResourceStringNode(ANode : TNode) : Boolean;
      begin
        Is_ConstResourceStringNode:=(ANode.NodeType=loadn) and
          (TLoadNode(ANode).SymTableEntry.Typ=constsym) and
          (TConstSym(TLoadNode(ANode).SymTableEntry).ConstTyp in [constresourcestring,constwresourcestring]);
      end;


    function Is_EmptySet(ANode : TNode):Boolean;
      begin
        Is_EmptySet:=(ANode.NodeType=setconstn) and
                     (TSetConstNode(ANode).ValueSet^=[]);
      end;


    function GenConstSymTree(ASym : TConstSym) : TNode;
      var
        lNode  : TNode;
        lLength : LongInt;
        lChars  : PChar;
        lValueSet : PConstSet;
      begin
        lNode:=nil;
        case ASym.ConstTyp of
          constord :
            begin
              if ASym.ConstDef=nil then
                InternalError(200403232);
              { no range checking; if it has a fixed type, the necessary value
                truncation was already performed at the declaration time }
              lNode:=COrdConstNode.Create(ASym.Value.ValueOrd,ASym.ConstDef,false);
            end;
          conststring :
            begin
              lLength:=ASym.Value.Len;
              if not(cs_refcountedstrings in CurrentSettings.LocalSwitches) and (lLength>255) then
                begin
                  message(parser_e_string_const_too_long);
                  lLength:=255;
                end;
              GetMem(lChars,lLength+1);
              move(PChar(ASym.Value.ValuePtr)^,lChars^,lLength);
              lChars[lLength]:=#0;
              lNode:=CStringConstNode.CreatePChar(lChars,lLength,ASym.ConstDef);
              FreeMem(lChars);
            end;
          constwstring :
            lNode:=CStringConstNode.CreateUniStr(ASym.Value.ValueWS);
          constreal :
            begin
              if (sp_generic_para in ASym.SymOptions) and not (sp_generic_const in ASym.SymOptions) then
                lNode:=CRealConstNode.Create(default(BestReal),ASym.ConstDef)
              else
                lNode:=CRealConstNode.Create(PBestReal(ASym.Value.ValuePtr)^,ASym.ConstDef);
            end;
          constset :
            begin
              if sp_generic_const in ASym.SymOptions then
                begin
                  New(lValueSet);
                  lValueSet^:=PConstSet(ASym.Value.ValuePtr)^;
                  lNode:=CSetConstNode.Create(lValueSet,ASym.ConstDef);
                end
              else if sp_generic_para in ASym.SymOptions then
                begin
                  New(lValueSet);
                  lNode:=CSetConstNode.Create(lValueSet,ASym.ConstDef);
                end
              else
                lNode:=CSetConstNode.Create(PConstSet(ASym.Value.ValuePtr),ASym.ConstDef);
            end;
          constpointer :
            begin
              if sp_generic_para in ASym.SymOptions then
                lNode:=CPointerConstNode.Create(default(TConstPtrUInt),ASym.ConstDef)
              else
                lNode:=CPointerConstNode.Create(ASym.Value.ValueOrdPtr,ASym.ConstDef);
            end;
          constnil :
            lNode:=CNilNode.Create;
          constguid :
            begin
              if sp_generic_para in ASym.SymOptions then
                lNode:=CGUIDConstNode.Create(default(TGUID))
              else
                lNode:=CGUIDConstNode.Create(PGUID(ASym.Value.ValuePtr)^);
            end;
          constnone :
            lNode:=CNothingNode.Create
          else
            InternalError(200205103);
        end;

        if Is_Currency(ASym.ConstDef) then
          Include(lNode.Flags, nf_is_currency);

        { transfer generic param flag from symbol to node }
        if sp_generic_para in ASym.SymOptions then
          include(lNode.Flags,nf_generic_para);
        GenConstSymTree:=lNode;
      end;


    function GetBooleanValue(ANode : TNode) : Boolean;
      begin
        if Is_ConstBoolNode(ANode) then
          Result:=TOrdConstNode(ANode).Value<>0
        else
          InternalError(2013111601);
      end;

{*****************************************************************************
                             TREALCONSTNODE
*****************************************************************************}

    { generic code     }
    { overridden by:   }
    {   i386           }
    constructor TRealConstNode.Create(AValue : BestReal;ADef:TDef);
      begin
         if ADef.Typ<>floatdef then
           InternalError(2002022402);
         inherited Create(realconstn);
         TypeDef:=ADef;
         SetCurrencyValue(AValue);
         case TFloatDef(ADef).FloatType of
           S32Real:
             AValue:=Single(AValue);
           S64Real:
             AValue:=Double(AValue);
           s80real,
           sc80real,
           s64comp,
           s64currency:
               ; { Keep the host's native precision. }
         end;
         ValueReal:=AValue;
         RealLabel:=nil;
      end;

    constructor TRealConstNode.Create_Currency_Scalar(ADef:TDef);
      begin
        Create(10000.0,ADef);
        Include(Flags,nf_internal);
        Include(Flags,nf_is_currency);
      end;


    function TRealConstNode.CurrencyScaledValue: Int64;
      begin
        if nf_is_currency in Flags then
          Result:=Round(ValueReal)
        else
          begin
            if FCurrencyRange<>crValid then
              CGMessage(parser_e_range_check_error);
            Move(ValueCurrency,Result,SizeOf(Result));
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
        Move(lRaw,ValueCurrency,SizeOf(lRaw));
      end;

    procedure TRealConstNode.SetCurrencyLiteral(const AText: ShortString);
      var
        lCode: Integer;
        lRaw: Int64;
      begin
        ValueCurrency:=ParseCurrencyLiteral(AText,lCode);
        if lCode=0 then
          FCurrencyRange:=crValid
        else
          begin
            FCurrencyRange:=crOverflow;
            { Preserve the unsigned magnitude of Low(Int64) until unary minus.
              Parse decimal digits directly, including on Double-only hosts. }
            if (Length(AText)<255) and (AText<>'') and (AText[1]<>'-') then
              begin
                ValueCurrency:=ParseCurrencyLiteral('-'+AText,lCode);
                Move(ValueCurrency,lRaw,SizeOf(lRaw));
                if (lCode=0) and (lRaw=Low(Int64)) then
                  FCurrencyRange:=crPositiveLimit;
              end;
          end;
      end;

    procedure TRealConstNode.NegateValue;
      var
        lRaw: Int64;
      begin
        ValueReal:=-ValueReal;
        Move(ValueCurrency,lRaw,SizeOf(lRaw));
        if FCurrencyRange=crPositiveLimit then
          FCurrencyRange:=crValid
        else if (FCurrencyRange=crValid) and (lRaw=Low(Int64)) then
          FCurrencyRange:=crPositiveLimit;
        {$push}{$Q-}
        lRaw:=-lRaw;
        {$pop}
        Move(lRaw,ValueCurrency,SizeOf(lRaw));
      end;

    constructor TRealConstNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      var
        lBits : Int64;
      begin
        inherited PPULoad(ANodeType,APPUFile);
        APPUFile.GetDeref(TypeDefDeref);
        ValueReal:=APPUFile.GetReal;
        lBits:=APPUFile.GetInt64;
        ValueCurrency:=PCurrency(@lBits)^;
        FCurrencyRange:=crValid;
        case APPUFile.GetByte of
          1: FCurrencyRange:=crPositiveLimit;
          2: FCurrencyRange:=crOverflow;
        end;
        RealLabel:=TAsmLabel(APPUFile.GetAsmSymbol);
      end;


    procedure TRealConstNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutDeref(TypeDefDeref);
        APPUFile.PutReal(ValueReal);
        APPUFile.PutInt64(PInt64(@ValueCurrency)^);
        APPUFile.PutByte(Ord(FCurrencyRange));
        APPUFile.PutAsmSymbol(RealLabel);
      end;


    procedure TRealConstNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        TypeDefDeref.Build(TypeDef);
      end;


    procedure TRealConstNode.DerefImpl;
      begin
        inherited DerefImpl;
        TypeDef:=TDef(TypeDefDeref.resolve);
      end;


    function TRealConstNode.DoGetCopy : TNode;
      var
         lCopy : TRealConstNode;
      begin
         lCopy:=TRealConstNode(inherited DoGetCopy);
         lCopy.TypeDef:=TypeDef;
         lCopy.ValueReal:=ValueReal;
         lCopy.ValueCurrency:=ValueCurrency;
         lCopy.FCurrencyRange:=FCurrencyRange;
         lCopy.RealLabel:=RealLabel;
         DoGetCopy:=lCopy;
      end;


    function TRealConstNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        ResultDef:=TypeDef;

        { range checking? }
        if Floating_Point_Range_Check_Error or
           (TFloatDef(ResultDef).FloatType in [s64comp,s64currency]) then
          begin
            { use CGMessage so that the resultdef will get set to errordef
              by pass1.typecheckpass_internal if a range error was triggered,
              which in turn will prevent any potential parent type conversion
              node from creating a new realconstnode with this exact same value
              and hence trigger the same error again }
            case TFloatDef(ResultDef).FloatType of
              S32Real :
                begin
                  if Single(ValueReal)=MathInf.Value then
                    CGMessage(parser_e_range_check_error);
                end;
              S64Real:
                begin
                  if Double(ValueReal)=MathInf.Value then
                    CGMessage(parser_e_range_check_error);
                end;
              s80real,
              sc80real:
                begin
                  if ValueReal=MathInf.Value then
                    CGMessage(parser_e_range_check_error);
                end;
              s64comp,
              s64currency:
                begin
                  if (ValueReal>BestReal(High(Int64))) or
                     (ValueReal<BestReal(Low(Int64))) then
                    CGMessage(parser_e_range_check_error)
                end;
            end;
          end;
      end;


    function TRealConstNode.Pass_1 : TNode;
      begin
         Result:=nil;
         expectloc:=LOC_CREFERENCE;
      end;


    function TRealConstNode.Simplify(AForInline : Boolean) : TNode;
      begin
        Result:=nil;
        if (Frac(ValueReal)<>0.0) and Is_Currency(ResultDef) and not (nf_is_currency in Flags) then
          begin
            { Unfortunately we can't safely store unscaled Currency values with
              fractional components in a cross-platform way, so scale it here
              so its 4 decimal places are preserved }
            ValueReal:=ValueReal*BestReal(10000.0);
            Include(Flags,nf_is_currency);
            Include(Flags,nf_internal);
          end;
      end;


    function TRealConstNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare :=
          inherited DoCompare(ANode) and
          { this should be always true }
          (TRealConstNode(ANode).TypeDef.Typ=floatdef) and (TypeDef.Typ=floatdef) and
          (TFloatDef(TypeDef).FloatType = TFloatDef(TRealConstNode(ANode).TypeDef).FloatType) and
          (
           (
            (TFloatDef(TypeDef).FloatType=s64currency) and
            (CurrencyScaledValue=TRealConstNode(ANode).CurrencyScaledValue)
           )
           or
           (
            (TFloatDef(TypeDef).FloatType<>s64currency) and
            (ValueReal=TRealConstNode(ANode).ValueReal) and
            (
              { Make sure 0.0 and -0.0 are not equated unless fastmath is enabled }
              (cs_opt_fastmath in CurrentSettings.OptimizerSwitches) or
              not (
                (
                  IsPosZero(ValueReal) and
                  IsNegZero(TRealConstNode(ANode).ValueReal)
                ) or
                (
                  IsNegZero(ValueReal) and
                  IsPosZero(TRealConstNode(ANode).ValueReal)
                )
              )
            ) and
            { floating point compares for non-numbers give strange results usually }
            Is_Number_Float(ValueReal) and
            Is_Number_Float(TRealConstNode(ANode).ValueReal)
           )
          );
      end;


    procedure TRealConstNode.PrintNodeData(var AText: text);
      begin
        inherited PrintNodeData(AText);
        write(AText,PrintNodeIndention,'value = ',RealToStr(ValueReal));
        if Is_Currency(ResultDef) then
          WriteLn(AText,', value_currency = ',ValueCurrency)
        else
          WriteLn(AText);
      end;

    function TRealConstNode.Emit_Data(ABuilder:TTAITypedConstBuilder):SizeInt;
      begin
        case TFloatDef(TypeDef).FloatType of
          S32Real:
            ABuilder.emit_tai(TAIRealConst.create_s32real(Single(ValueReal)),TypeDef);
          S64Real:
            ABuilder.emit_tai(TAIRealConst.create_s64real(Double(ValueReal)),TypeDef);
          s80real:
            ABuilder.emit_tai(TAIRealConst.create_s80real(ValueReal,S80FloatType.Size),TypeDef);
          sc80real:
            ABuilder.emit_tai(TAIRealConst.create_s80real(ValueReal,SC80FloatType.Size),TypeDef);
          s64comp:
            { the round is necessary for native compilers where comp isn't a float }
            ABuilder.emit_tai(TAIRealConst.create_s64compreal(Round(ValueReal)),TypeDef);
          s64currency:
            { Lowered Currency nodes already contain the integer payload. }
            ABuilder.emit_tai(TAIRealConst.create_s64compreal(Round(ValueReal)),TypeDef);
        end;
        Result:=ResultDef.Size;
      end;


{*****************************************************************************
                              TORDCONSTNODE
*****************************************************************************}

    constructor TOrdConstNode.Create(const AValue : TConstExprInt;ADef:TDef;ARangeCheck : Boolean);

      begin
         inherited Create(ordconstn);
         Value:=AValue;
         TypeDef:=ADef;
         RangeCheck := ARangeCheck;
      end;


    constructor TOrdConstNode.Create_Currency_Scalar(ADef:TDef);
      begin
        Create(10000,ADef,false);
        Include(Flags,nf_internal);
        Include(Flags,nf_is_currency);
      end;


    constructor TOrdConstNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        APPUFile.GetDeref(TypeDefDeref);
        Value:=APPUFile.GetExprInt;
        { normally, the value is already compiled, so we don't need
          to do once again a range check
        }
        RangeCheck := false;
      end;


    procedure TOrdConstNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutDeref(TypeDefDeref);
        APPUFile.PutExprInt(Value);
      end;


    procedure TOrdConstNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        TypeDefDeref.Build(TypeDef);
      end;


    procedure TOrdConstNode.DerefImpl;
      begin
        inherited DerefImpl;
        TypeDef:=TDef(TypeDefDeref.resolve);
      end;


    function TOrdConstNode.DoGetCopy : TNode;

      var
         lCopy : TOrdConstNode;

      begin
         lCopy:=TOrdConstNode(inherited DoGetCopy);
         lCopy.Value:=Value;
         lCopy.TypeDef := TypeDef;
         DoGetCopy:=lCopy;
      end;

    function TOrdConstNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        ResultDef:=TypeDef;
        { only do range checking when explicitly asked for it
          and if the type can be range checked, see tests/tbs/tb0539.pas }
        if (ResultDef.Typ in [orddef,enumdef]) and not(nf_generic_para in Flags) then
          AdaptRange(ResultDef,Value,nf_internal in Flags,not RangeCheck,RangeCheck)
      end;

    function TOrdConstNode.Pass_1 : TNode;
      begin
         Result:=nil;
         expectloc:=LOC_CONSTANT;
      end;

    function TOrdConstNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare :=
          inherited DoCompare(ANode) and
          (Value = TOrdConstNode(ANode).Value) and
          Equal_Defs(TypeDef,TOrdConstNode(ANode).TypeDef);
      end;


    procedure TOrdConstNode.PrintNodeData(var AText: text);
      begin
        inherited PrintNodeData(AText);
        WriteLn(AText,PrintNodeIndention,'typedef = "',TypeDef.GetTypeName,'"');
        WriteLn(AText,PrintNodeIndention,'value = ',ToStr(Value));
      end;

    function TOrdConstNode.Emit_Data(ABuilder:TTAITypedConstBuilder):SizeInt;
      begin
        ABuilder.emit_ord_const(Value,ResultDef);
        Result:=ResultDef.Size;
      end;


{*****************************************************************************
                            TPOINTERCONSTNODE
*****************************************************************************}

    constructor TPointerConstNode.Create(AValue : TConstPtrUInt;ADef:TDef);
      begin
        inherited Create(pointerconstn);
        Value:=AValue;
        TypeDef:=ADef;
      end;


    constructor TPointerConstNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        APPUFile.GetDeref(TypeDefDeref);
        Value:=APPUFile.GetPtrUInt;
      end;


    procedure TPointerConstNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutDeref(TypeDefDeref);
        APPUFile.PutPtrUInt(Value);
      end;


    procedure TPointerConstNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        TypeDefDeref.Build(TypeDef);
      end;


    procedure TPointerConstNode.DerefImpl;
      begin
        inherited DerefImpl;
        TypeDef:=TDef(TypeDefDeref.resolve);
      end;


    function TPointerConstNode.DoGetCopy : TNode;
      var
         lCopy : TPointerConstNode;
      begin
        lCopy:=TPointerConstNode(inherited DoGetCopy);
        lCopy.Value:=Value;
        lCopy.TypeDef := TypeDef;
        DoGetCopy:=lCopy;
      end;


    function TPointerConstNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        ResultDef:=TypeDef;
        if Is_VoidPointer(ResultDef) and (Value=0) then
          Result:=CNilNode.Create;
      end;


    function TPointerConstNode.Pass_1 : TNode;
      begin
        Result:=nil;
        expectloc:=LOC_CONSTANT;
      end;


    function TPointerConstNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare :=
          inherited DoCompare(ANode) and
          (Value = TPointerConstNode(ANode).Value);
      end;


    procedure TPointerConstNode.PrintNodeData(var AText : text);
      begin
        inherited PrintNodeData(AText);
        WriteLn(AText,PrintNodeIndention,'value = $',HexStr(PUint(Value),sizeof(PUint)*2));
      end;

    function TPointerConstNode.Emit_Data(ABuilder: TTAITypedConstBuilder): SizeInt;
      begin
        if TPointerDef(ResultDef).Compatible_With_PointerDef_Size(TPointerDef(VoidPointerType)) then
          ABuilder.emit_tai(TAIConst.Create_int_dataptr(Value),VoidPointerType)
        else
          ABuilder.emit_tai(TAIConst.Create_int_codeptr(Value),VoidCodePointerType);
        Result:=ResultDef.Size;
      end;


{*****************************************************************************
                             TSTRINGCONSTNODE
*****************************************************************************}

    constructor TStringConstNode.CreateStr(const AString : string);
      var
         lLength : LongInt;
      begin
         inherited Create(stringconstn);
         lLength:=length(AString);
         Len:=lLength;
         { stringdup write even past a #0 }
         SetLength(ValueAS,lLength+1);
         ValueAS[lLength]:=#0;
         if lLength>0 then
           move(AString[1],ValueAS[0],lLength);
         StringLabel:=nil;
         ConstStringType:=cst_conststring;
      end;


    constructor TStringConstNode.CreateUniStr(AWideString : TCompilerWideString);
      begin
         inherited Create(stringconstn);
         Len:=GetLengthWideString(AWideString);
         InitWideString(ValueWS);
         CopyWideString(AWideString,ValueWS);
         StringLabel:=nil;
         ConstStringType:=cst_unicodestring;
      end;


    constructor TStringConstNode.CreatePChar(AChars: PChar; ALength: LongInt; ADef: TDef);
      begin
         inherited Create(stringconstn);
         Len:=ALength;
         SetLength(ValueAS,ALength+1);
         ValueAS[ALength]:=#0;
         if ALength>0 then
           move(AChars[0],ValueAS[0],ALength);
         if Assigned(ADef) and
            Is_AnsiString(ADef) then
           begin
             ConstStringType:=cst_ansistring;
             AStringDef:=ADef;
           end
         else
           ConstStringType:=cst_conststring;
         StringLabel:=nil;
      end;


    destructor TStringConstNode.Destroy;
      begin
        if ConstStringType in [cst_widestring,cst_unicodestring] then
          DoneWideString(ValueWS)
        else
          ValueAS:=nil;
        inherited Destroy;
      end;


    constructor TStringConstNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      var
        lIndex : LongInt;
      begin
        inherited PPULoad(ANodeType,APPUFile);
        ConstStringType:=TConstStringType(APPUFile.GetByte);
        Len:=APPUFile.GetLongInt;
        if ConstStringType in [cst_widestring,cst_unicodestring] then
          begin
            InitWideString(ValueWS);
            SetLengthWideString(ValueWS,Len);
            { don't use getdata, because the compilerwidechars may have to
              be byteswapped
            }
            for lIndex:=0 to ValueWS.Len-1 do
              ValueWS.data[lIndex]:=APPUFile.GetWord;
          end
        else
          begin
            SetLength(ValueAS,Len+1);
            ValueAS[Len]:=#0;
            if Len>0 then
              APPUFile.GetData(ValueAS[0],Len);
          end;
        StringLabel:=TAsmLabel(APPUFile.GetAsmSymbol);
        if ConstStringType=cst_ansistring then
          APPUFile.GetDeref(AStringDefDeref);
      end;


    procedure TStringConstNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutByte(Byte(ConstStringType));
        APPUFile.PutLongInt(Len);
        if Len>0 then
          if ConstStringType in [cst_widestring,cst_unicodestring] then
            APPUFile.PutData(ValueWS.data[0],Len*sizeof(TCompilerWideChar))
          else
            APPUFile.PutData(ValueAS[0],Len);
        APPUFile.PutAsmSymbol(StringLabel);
        if ConstStringType=cst_ansistring then
          APPUFile.PutDeref(AStringDefDeref);
      end;


    procedure TStringConstNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        if ConstStringType=cst_ansistring then
          AStringDefDeref.Build(AStringDef);
      end;


    procedure TStringConstNode.DerefImpl;
      begin
        inherited DerefImpl;
        if ConstStringType=cst_ansistring then
          AStringDef:=TDef(AStringDefDeref.resolve);
      end;


    function TStringConstNode.DoGetCopy : TNode;

      var
         lCopy : TStringConstNode;

      begin
         lCopy:=TStringConstNode(inherited DoGetCopy);
         lCopy.ConstStringType:=ConstStringType;
         lCopy.Len:=Len;
         lCopy.StringLabel:=StringLabel;
         if ConstStringType in [cst_widestring,cst_unicodestring] then
           begin
             InitWideString(lCopy.ValueWS);
             CopyWideString(ValueWS,lCopy.ValueWS);
           end
         else
           begin
           SetLength(lCopy.ValueAS,Len+1);
           lCopy.ValueAS[Len]:=#0;
           if Len>0 then
             move(ValueAS[0],lCopy.ValueAS[0],Len);
           end;
         lCopy.AStringDef:=AStringDef;
         DoGetCopy:=lCopy;
      end;


    function TStringConstNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        case ConstStringType of
          cst_conststring :
            begin
              { handle and store as array[0..len-1] of char }
              ResultDef:=CArrayDef.Create(0,Len-1,S32IntType);
              TArrayDef(ResultDef).ElementDef:=CAnsiCharType;
              include(TArrayDef(ResultDef).ArrayOptions,ado_IsConstString);
            end;
          cst_shortstring :
            ResultDef:=CShortStringType;
          cst_ansistring :
            if not Assigned(AStringDef) then
              ResultDef:=GetAnsiStringDef
            else
              ResultDef:=AStringDef;
          cst_unicodestring :
            ResultDef:=CUnicodeStringType;
          cst_widestring :
            ResultDef:=CWideStringType;
          cst_longstring :
            ResultDef:=CLongStringType;
        end;
      end;


    function TStringConstNode.Pass_1 : TNode;
      begin
        Result:=nil;
        if (ConstStringType in [cst_ansistring,cst_widestring,cst_unicodestring]) then
          begin
            if Len=0 then
              expectloc:=LOC_CONSTANT
            else
              expectloc:=LOC_REGISTER
          end
        else
          expectloc:=LOC_CREFERENCE;
      end;


    function TStringConstNode.GetPCharCopy : PChar;
      var
         lChars : PChar;
      begin
         lChars:=nil;
         GetMem(lChars,Len+1);
         if lChars=nil then
           Message(general_f_no_memory_left);
         lChars[Len]:=#0;
         if Len>0 then
           move(ValueAS[0],lChars^,Len);
         GetPCharCopy:=lChars;
      end;

    function TStringConstNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare :=
          inherited DoCompare(ANode) and
          (Len = TStringConstNode(ANode).Len) and
          (StringLabel = TStringConstNode(ANode).StringLabel) and
          { This is enough as soon as labels are allocated, otherwise }
          { fall back to content compare.                             }
          (Assigned(StringLabel) or
            (ConstStringType = TStringConstNode(ANode).ConstStringType) and
            (FullCompare(TStringConstNode(ANode)) = 0))
          ;
      end;


    procedure TStringConstNode.ChangeStringType(ADef:TDef);
      const
        ST2CST : array[TStringType] of TConstStringType = (
          cst_shortstring,cst_longstring,cst_ansistring,cst_widestring,cst_unicodestring);
      var
        lWideString : TCompilerWideString;
        lChars : PChar;
        lSourceEncoding : TStringEncoding;
        lTargetEncoding : TStringEncoding;
        lLength,lLength2 : LongInt;
      begin
        if ADef.Typ<>stringdef then
          InternalError(200510011);
        { convert ascii 2 unicode }
        if (TStringDef(ADef).StringType in [st_widestring,st_unicodestring]) and
           not(ConstStringType in [cst_widestring,cst_unicodestring]) then
          begin
            InitWideString(ValueWS);
            ASCII2Unicode(AsConstPChar,Len,CurrentSettings.SourceCodePage,ValueWS);
          end
        else
          { convert unicode 2 ascii }
          if (ConstStringType in [cst_widestring,cst_unicodestring]) and
            not(TStringDef(ADef).StringType in [st_widestring,st_unicodestring]) then
            begin
              lSourceEncoding:=TStringDef(ADef).encoding;
              if (lSourceEncoding=Globals.CP_NONE) or (lSourceEncoding=0) then
                lSourceEncoding:=CurrentSettings.SourceCodePage;
              if (lSourceEncoding=CP_UTF8) then
                begin
                  lLength2:=Len;
                  lLength:=UnicodeToUtf8(nil,0,ValueWS.AsConstPUnicodeChar,lLength2);
                  SetLength(ValueAS,lLength+1);
                  ValueAS[lLength]:=#0;
                  if lLength>0 then
                    UnicodeToUtf8(AsConstPChar,lLength,ValueWS.AsConstPUnicodeChar,lLength2);
                  Len:=lLength-1;
                  DoneWideString(ValueWS);
                end
              else
                begin
                  SetLength(ValueAS,GetLengthWideString(ValueWS)+1);
                  Len:=Length(ValueAS)-1;
                  Unicode2ASCII(ValueWS,AsConstPChar,lSourceEncoding);
                  DoneWideString(ValueWS);
                end;
            end
        else
          if (TStringDef(ADef).StringType = st_ansistring) and
             not(ConstStringType in [cst_widestring,cst_unicodestring]) then
            begin
              lSourceEncoding:=TStringDef(ADef).encoding;
              if lSourceEncoding=0 then
                lSourceEncoding:=CurrentSettings.SourceCodePage;
              if (ConstStringType = cst_ansistring) then
                begin
                  lTargetEncoding:=TStringDef(ResultDef).encoding;
                  if lTargetEncoding=0 then
                    lTargetEncoding:=CurrentSettings.SourceCodePage;
                end
              else if (ConstStringType in [cst_shortstring,cst_conststring,cst_longstring]) then
                lTargetEncoding:=CurrentSettings.SourceCodePage
              else
                InternalError(2013112916);
              { don't change string if codepages are equal or string length is 0 }
              if (lSourceEncoding<>lTargetEncoding) and (Len>0) then
                begin
                  if CPAvailable(lSourceEncoding) and CPAvailable(lTargetEncoding) then
                    ChangeCodePage(AsConstPChar,Len,lTargetEncoding,AsConstPChar,lSourceEncoding)
                  else if (lSourceEncoding <> Globals.CP_NONE) and (lTargetEncoding <> Globals.CP_NONE) then
                    begin
                      { if source encoding is UTF8 convert using UTF8->UTF16->destination encoding }
                      if (lTargetEncoding=CP_UTF8) then
                        begin
                          if not CPAvailable(lSourceEncoding) then
                            begin
                              Message1(option_code_page_not_available,IntToStr(lSourceEncoding));
                              exit;
                            end;
                          InitWideString(lWideString);
                          SetLengthWideString(lWideString,Len);
                          { returns room for terminating 0 }
                          if Len>0 then
                            lLength:=Utf8ToUnicode(lWideString.AsConstPUnicodeChar,Len,AsConstPChar,Len)
                          else
                            lLength:=1;
                          if (lLength<>GetLengthWideString(lWideString)) then
                            begin
                              SetLengthWideString(lWideString,lLength);
                              SetLength(ValueAS,lLength);
                              ValueAS[lLength-1]:=#0;
                            end;
                          Unicode2ASCII(lWideString,ValueAS,lSourceEncoding);
                          Len:=lLength-1;
                          DoneWideString(lWideString);
                        end
                      else
                      { if destination encoding is UTF8 convert using source encoding->UTF16->UTF8 }
                      if (lSourceEncoding=CP_UTF8) then
                        begin
                          if not CPAvailable(lTargetEncoding) then
                            begin
                              Message1(option_code_page_not_available,IntToStr(lTargetEncoding));
                              exit;
                            end;
                          InitWideString(lWideString);
                          SetLengthWideString(lWideString,Len);
                          ASCII2Unicode(AsConstPChar,Len,lTargetEncoding,lWideString);
                          { returns room for terminating 0 }
                          lLength:=UnicodeToUtf8(nil,0,lWideString.AsConstPUnicodeChar,Len);
                          if lLength<>Len then
                            begin
                            SetLength(ValueAS,lLength);
                            ValueAS[lLength-1]:=#0;
                            end;
                          UnicodeToUtf8(AsConstPChar,lLength,lWideString.AsConstPUnicodeChar,Len);
                          Len:=lLength-1;
                          DoneWideString(lWideString);
                        end
                      else
                        begin
                          { output error message that encoding is not available for the compiler }
                          if not CPAvailable(lSourceEncoding) then
                            Message1(option_code_page_not_available,IntToStr(lSourceEncoding));
                          if not CPAvailable(lTargetEncoding) then
                            Message1(option_code_page_not_available,IntToStr(lTargetEncoding));
                        end;
                    end;
                end;
            end;
        ConstStringType:=ST2CST[TStringDef(ADef).StringType];
        ResultDef:=ADef;
      end;

    function TStringConstNode.FullCompare(ANode: TStringConstNode): LongInt;
      begin
        if ConstStringType<>ANode.ConstStringType then
          InternalError(2009121701);
        if ConstStringType in [cst_widestring,cst_unicodestring] then
          Result:=CompareWideStrings(ValueWS,ANode.ValueWS)
        else
          Result:=CompareAnsiStrings(AsConstPChar,ANode.AsConstPChar,Len,ANode.Len);
      end;

    function TStringConstNode.Emit_Data(ABuilder:TTAITypedConstBuilder):SizeInt;
      var
        lShortString : ShortString;
        lLabelOffset : TAsmLabOfs;
        lWinLikeWideString : Boolean;
      begin
        case TStringDef(ResultDef).StringType of
          st_shortstring:
            begin
              SetLength(lShortString,Len);
              if Len>0 then
                move(ValueAS[0],lShortString[1],Len);
              ABuilder.emit_shortstring_const(lShortString);
              Result:=Len+1;
            end;
          st_longstring:
            InternalError(2019070801);
          st_ansistring:
            begin
              lLabelOffset:=ABuilder.emit_ansistring_const(CurrentAsmData.asmlists[al_typedconsts],AsConstPChar,Len,TStringDef(ResultDef).encoding);
              ABuilder.emit_string_offset(lLabelOffset,Len,TStringDef(ResultDef).StringType,false,CharPointerType);
              Result:=VoidPointerType.Size;
            end;
          st_widestring,
          st_unicodestring:
            begin
              lWinLikeWideString:=(ConstStringType=cst_widestring) and (tf_winlikewidestring in TargetInfo.Flags);
              lLabelOffset:=ABuilder.emit_unicodestring_const(CurrentAsmData.asmlists[al_typedconsts],ValueWS,TStringDef(ResultDef).encoding,lWinLikeWideString);
              ABuilder.emit_string_offset(lLabelOffset,Len,TStringDef(ResultDef).StringType,false,WideCharPointerType);
              Result:=VoidPointerType.Size;
            end;
        end;
      end;

    function TStringConstNode.AsRawByteString: RawByteString;
    begin
      Result:='';
      if Length(ValueAS)>0 then
        Result:=PChar(@ValueAS[0]);
    end;

    var
      cEmptyString : ansichar = #0;

    function TStringConstNode.AsConstPChar: PChar;
    begin
      if length(ValueAS)>0 then
        Result:=@ValueAS[0]
      else
        Result:=@cEmptyString;
    end;

    class function TStringConstNode.EmptyDynStrNil: Boolean;
      begin
        Result:=true;
      end;

      procedure TStringConstNode.PrintNodeData(var AText: Text);
      var
        lUnicodeString : UnicodeString;

      begin
        inherited PrintNodeData(AText);
        if length(ValueAS)>0 then
          WriteLn(AText,PrintNodeIndention,'value = "',PAnsiChar(@ValueAS[0]),'"')
        else if Assigned(ValueWS) and (ValueWS.Len>0) then
          begin
          SetLength(lUnicodeString,ValueWS.Len);
          move(ValueWS.data[0],lUnicodeString[1],ValueWS.Len*sizeof(unicodechar));
          WriteLn(AText,PrintNodeIndention,'value = "',lUnicodeString,'"');
          end
        else
          WriteLn(AText,PrintNodeIndention,'value = ""');
      end;


{*****************************************************************************
                             TSETCONSTNODE
*****************************************************************************}

    constructor TSetConstNode.Create(ASet : PConstSet;ADef:TDef);

      begin
         inherited Create(setconstn,nil);
         TypeDef:=ADef;
         if Assigned(ASet) then
           begin
              New(ValueSet);
              ValueSet^:=ASet^;
           end
         else
           ValueSet:=nil;
      end;


    destructor TSetConstNode.Destroy;
      begin
        if Assigned(ValueSet) then
         dispose(ValueSet);
        inherited Destroy;
      end;


    constructor TSetConstNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        APPUFile.GetDeref(TypeDefDeref);
        New(ValueSet);
        APPUFile.GetSet(TPPUSet32(ValueSet^));
      end;


    procedure TSetConstNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutDeref(TypeDefDeref);
        APPUFile.PutSet(TPPUSet32(ValueSet^));
      end;


    procedure TSetConstNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        TypeDefDeref.Build(TypeDef);
      end;


    procedure TSetConstNode.DerefImpl;
      begin
        inherited DerefImpl;
        TypeDef:=TDef(TypeDefDeref.resolve);
      end;

    type
       TSetBytes = array[0..31] of Byte;
       PSetBytes = ^TSetBytes;

    procedure TSetConstNode.AdjustForSetBase;
      var
        lIndex, lDifference: LongInt;
      begin
        { Internally, the compiler stores all sets with setbase 0, so we have }
        { to convert the set to its actual format in case setbase<>0 when     }
        { writing it out                                                      }
        if (TSetDef(ResultDef).SetBase<>0) then
          begin
            if (TSetDef(ResultDef).SetBase and 7)<>0 then
              InternalError(2007091501);
            lDifference:=TSetDef(ResultDef).SetBase div 8;
            { This is endian-neutral in the new set format: in both cases, }
            { the first byte contains the first elements of the set.       }
            { Since the compiler/base rtl cannot contain packed sets before }


            { <>0 with non-packed sets).                                    }
            for lIndex:=0 to TSetDef(ResultDef).Size-1 do
              begin
                PSetBytes(ValueSet)^[lIndex]:=PSetBytes(ValueSet)^[lIndex+lDifference];
                PSetBytes(ValueSet)^[lIndex+lDifference]:=0;
              end;
          end;
      end;


    function TSetConstNode.DoGetCopy : TNode;
      var
         lCopy : TSetConstNode;
      begin
         lCopy:=TSetConstNode(inherited DoGetCopy);
         if Assigned(ValueSet) then
           begin
              New(lCopy.ValueSet);
              lCopy.ValueSet^:=ValueSet^
           end
         else
           lCopy.ValueSet:=nil;
         lCopy.TypeDef := TypeDef;
         lCopy.DataLabel:=DataLabel;
         DoGetCopy:=lCopy;
      end;


    function TSetConstNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        ResultDef:=TypeDef;
      end;


    function TSetConstNode.Pass_1 : TNode;
      begin
         Result:=nil;
         if Is_SmallSet(ResultDef) then
          expectloc:=LOC_CONSTANT
         else
          expectloc:=LOC_CREFERENCE;
      end;


    function TSetConstNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare:=(inherited DoCompare(ANode)) and
                   (ValueSet^=TSetConstNode(ANode).ValueSet^);
      end;


    function TSetConstNode.Elements : AInt;
      var
        lIndex : LongInt;
      begin
        Result:=0;
        if not(Assigned(ValueSet)) then
          exit;
        for lIndex:=0 to TSetDef(ResultDef).Size-1 do
          Result:=Result+ PopCnt(PSetBytes(ValueSet)^[lIndex]);
      end;


    function TSetConstNode.Low: AInt;
      var
        lIndex: ASizeInt;
      begin
        Result:=0;
        if not(Assigned(ValueSet)) then
          exit;
        lIndex:=0;
        while lIndex<=TSetDef(ResultDef).SetMax do
          begin
            if lIndex in ValueSet^ then
              begin
                Result:=lIndex;
                exit;
              end;
            inc(lIndex);
          end;
      end;


    function TSetConstNode.High: AInt;
      var
        lIndex: ASizeInt;
      begin
        Result:=0;
        if not(Assigned(ValueSet)) then
          exit;
        lIndex:=TSetDef(ResultDef).SetMax;
        while lIndex>=TSetDef(ResultDef).SetBase do
          begin
            if lIndex in ValueSet^ then
              begin
                Result:=lIndex;
                exit;
              end;
            dec(lIndex);
          end;
      end;


    function TSetConstNode.Emit_Data(ABuilder:TTAITypedConstBuilder):SizeInt;
      type
        TSetBytes=array[0..31] of Byte;
        PSetBytes=^TSetBytes;
      var
        lSetValue : AInt;
        lIndex : SizeInt;
      begin
        if Is_SmallSet(ResultDef) then
          begin
            begin
                { not plongint, because that will "sign extend" the set on 64 bit platforms }
                { if changed to "paword", please also modify "32-resultdef.size*8" and      }

                { Extra aint type cast to avoid range errors                                }
                 lSetValue:=AInt(pCardinal(ValueSet)^)
              end;
            case ResultDef.Size of
              1:
                ABuilder.emit_ord_const(Byte(lSetValue),U8IntType);
              2:
                ABuilder.emit_ord_const(word(lSetValue),U16IntType);
              4:
                ABuilder.emit_ord_const(LongWord(lSetValue),U32IntType);
              8:
                ABuilder.emit_ord_const(qword(lSetValue),U64IntType);
              else
                InternalError(2019070802);
            end;
          end
        else
          begin
            for lIndex:=0 to ResultDef.Size-1 do
                ABuilder.emit_tai(TAIConst.create_8bit(PSetBytes(ValueSet)^[lIndex]),U8IntType);
          end;
        Result:=ResultDef.Size;
      end;


{*****************************************************************************
                               TNILNODE
*****************************************************************************}

    constructor TNilNode.Create;

      begin
        inherited Create(niln);
      end;

    function TNilNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        ResultDef:=VoidPointerType;
      end;

    function TNilNode.Emit_Data(ABuilder: TTAITypedConstBuilder): SizeInt;
      begin
        if TPointerDef(ResultDef).Compatible_With_PointerDef_Size(TPointerDef(VoidPointerType)) then
          ABuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType)
        else
          ABuilder.emit_tai(TAIConst.Create_nil_codeptr,VoidCodePointerType);
        Result:=ResultDef.Size;
      end;

    function TNilNode.Pass_1 : TNode;
      begin
        Result:=nil;
        expectloc:=LOC_CONSTANT;
      end;

{*****************************************************************************
                            TGUIDCONSTNODE
*****************************************************************************}

    constructor TGUIDConstNode.Create(const AGUID:TGUID);

      begin
         inherited Create(guidconstn);
         Value:=AGUID;
      end;

    constructor TGUIDConstNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        APPUFile.GetGUID(Value);
      end;


    procedure TGUIDConstNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutGUID(Value);
      end;


    function TGUIDConstNode.DoGetCopy : TNode;
      var
         lCopy : TGUIDConstNode;
      begin
         lCopy:=TGUIDConstNode(inherited DoGetCopy);
         lCopy.Value:=Value;
         lCopy.DataLabel:=DataLabel;
         DoGetCopy:=lCopy;
      end;


    function TGUIDConstNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        ResultDef:=Rec_TGUID;
      end;


    function TGUIDConstNode.Pass_1 : TNode;
      begin
         Result:=nil;
         expectloc:=LOC_CREFERENCE;
      end;


    function TGUIDConstNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare :=
          inherited DoCompare(ANode) and
          (GUID2String(Value) = GUID2String(TGUIDConstNode(ANode).Value));
      end;

    function TGUIDConstNode.Emit_Data(ABuilder: TTAITypedConstBuilder): SizeInt;
      begin
        ABuilder.emit_guid_const(Value);
        Result:=ResultDef.Size;
      end;

end.
