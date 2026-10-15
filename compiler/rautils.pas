{
    Copyright (c) 1998-2002 by Carl Eric Codere and Peter Vreman

    This unit implements some support routines for assembler parsing
    independent of the processor

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

 **********************************************************************}
Unit RAUtils;

{$i fpcdefs.inc}

Interface

Uses
  TPCompilerReal,
  CUtils,CClasses,
  GlobType,aasmbase,aasmtai,AAsmData,cpubase,CPUInfo,cgbase,cgutils,
  symconst,SymBase,symtype,symdef,SymSym,ConstExp,symcpu;

Const
  RPNMax = 10;             { I think you only need 4, but just to be safe }
  OpMax  = 25;

Function SearchLabel(const s: string; var hl: TAsmLabel;emit:boolean): boolean;


{---------------------------------------------------------------------
                 Instruction management
---------------------------------------------------------------------}

type
  TOprType=(OPR_NONE,OPR_CONSTANT,OPR_SYMBOL,OPR_LOCAL,
            OPR_REFERENCE,OPR_REGISTER,OPR_COND,OPR_REGSET,
            OPR_SHIFTEROP,OPR_MODEFLAGS,OPR_SPECIALREG,
            OPR_REGPAIR,OPR_FENCEFLAGS,OPR_INDEXEDREG,OPR_FLOATCONSTANT,
            OPR_FUNCTYPE);

  TOprRec = record
    case typ:TOprType of
      OPR_NONE      : ();

      OPR_CONSTANT  : (val:aint);

      OPR_SYMBOL    : (symbol:TAsmSymbol;symofs:aint;symseg:boolean;sym_farproc_entry:boolean);
      OPR_REFERENCE : (varsize:asizeint; constoffset: asizeint;ref_farproc_entry:boolean;ref:TReference);
      OPR_LOCAL     : (localvarsize, localconstoffset: asizeint;localsym:TAbstractNormalVarSym;localsymofs:aint;localsegment,localindexreg:TRegister;localscale:byte;localgetoffset,localforceref:boolean);
      OPR_REGISTER  : (reg:TRegister);
{$ifdef aarch64}
      OPR_REGSET    : (basereg: TRegister; nregs, regsetindex: byte);
      OPR_INDEXEDREG: (indexedreg: TRegister; regindex: byte);
      OPR_SHIFTEROP : (shifterop : TShifterOp);
      OPR_COND      : (cc : TAsmCond);
{$endif aarch64}
  end;

  TInstruction = class;

  TOperand = class
    opr    : TOprRec;
    typesize : byte;
    haslabelref,      { if the operand has a label, used in a reference like a
                        var (e.g. 'mov ax, word ptr [label+5]', but *not*
                        e.g. 'jmp label') }
    hasproc,          { if the operand has a procedure/function reference }
    hastype,          { if the operand has typecasted variable }
    hasvar : boolean; { if the operand is loaded with a variable }
    size   : TCgSize;
    constructor create;virtual;
    destructor  Destroy;override;
    Procedure SetSize(_size:LongInt;force:boolean);virtual;
    Procedure SetCorrectSize(opcode:TAsmOp);virtual;
    Function  SetupResult:boolean;virtual;
    Function  SetupSelf:boolean;
    Function  SetupOldEBP:boolean;
    Function  SetupVar(const s:string;GetOffset : boolean): Boolean;
    function CheckOperand(ins : TInstruction): boolean; virtual;
    Procedure InitRef;
    Procedure InitRefConvertLocal;
   protected
    Procedure InitRefError;
  end;
  TCOperand = class of TOperand;

  TInstruction = class
    operands  : array[1..max_operands] of TOperand;
    opcode    : TAsmOp;
    condition : TAsmCond;
    ops       : byte;
    labeled   : boolean;
    filepos  : TFilePosInfo;
    constructor create(optype : TCOperand);virtual;
    destructor  Destroy;override;
    { converts the instruction to an instruction how it's used by the assembler writer
      and concatenate it to the passed list. The newly created item is returned if the
      instruction was valid, otherwise nil is returned }
    function ConcatInstruction(p:TAsmList) : TAI;virtual;
  end;

  {---------------------------------------------------------------------}
  {                   Expression parser types                           }
  {---------------------------------------------------------------------}

   TExprOperator = record
    ch: char;           { operator }
    is_prefix: boolean; { was it a prefix, possible prefixes are +,- and not }
   end;

  {**********************************************************************}
  { The following operators are supported:                              }
  {  '+' : addition                                                     }
  {  '-' : subtraction                                                  }
  {  '*' : multiplication                                               }
  {  '/' : modulo division                                              }
  {  '^' : exclusive or                                                 }
  {  '<' : shift left                                                   }
  {  '>' : shift right                                                  }
  {  '&' : bitwise and                                                  }
  {  '|' : bitwise or                                                   }
  {  '~' : bitwise complement                                           }
  {  '%' : modulo division                                              }
  {  nnn: longint numbers                                               }
  {  ( and ) parenthesis                                                }
  {  [ and ] another kind of parenthesis                                }
  {**********************************************************************}

  TExprParse = class
    public
     Constructor create;
     Destructor Destroy;override;
     Function Evaluate(Expr:  String): TCGInt;
     Function Priority(_Operator: Char): aint;
    private
     RPNStack   : Array[1..RPNMax] of TCGInt;        { Stack For RPN calculator }
     RPNTop     : TCGInt;
     OpStack    : Array[1..OpMax] of TExprOperator;    { Operator stack For conversion }
     OpTop      : TCGInt;
     Procedure RPNPush(Num: TCGInt);
     Function RPNPop: TCGInt;
     Procedure RPNCalc(const token: String; prefix: boolean);
     Procedure OpPush(_Operator: char; prefix: boolean);
     { In reality returns TExprOperator }
     Procedure OpPop(var _Operator:TExprOperator);
  end;

  { Evaluate an expression string to a tcgint }
  Function CalculateExpression(const expression: string): TCGInt;

  {---------------------------------------------------------------------}
  {                     String routines                                 }
  {---------------------------------------------------------------------}

Function ParseVal(const S:String;base:byte):TCGInt;
Function PadZero(Var s: ShortString; n: byte): Boolean;
Function EscapeToPascal(const s:ShortString): ShortString;

{---------------------------------------------------------------------
                     Symbol helper routines
---------------------------------------------------------------------}

procedure AsmSearchSym(const s:string;out srsym:TSym;out srsymtable:TSymTable);
Function GetRecordOffsetSize(s:string;out Offset: TCGInt;out Size:TCGInt; out MangledName: string; needvmtofs: boolean; out hastypecast: boolean):boolean;
Function SearchType(const hs:string;out size:TCGInt): Boolean;
Function SearchRecordType(const s:string): boolean;
Function SearchIConstant(const s:string; var l:TCGInt): boolean;
Function AsmRegisterPara(sym: TAbstractNormalVarSym): boolean;

{---------------------------------------------------------------------
                  Instruction generation routines
---------------------------------------------------------------------}

  Procedure ConcatLabel(p: TAsmList;var l : TAsmLabel);
  Procedure ConcatConstant(p : TAsmList;value: TCGInt; constsize:byte);
  Procedure ConcatConstSymbol(p : TAsmList;const sym,endsym:string;symtyp:TAsmsymtype;l:TCGInt;constsize:byte;isofs:boolean);
  Procedure ConcatRealConstant(p : TAsmList;value: BestReal; real_typ : TFloatType);
  Procedure ConcatString(p : TAsmList;s:string);
  procedure ConcatAlign(p:TAsmList;l:TCGInt);
  Procedure ConcatPublic(p:TAsmList;const s : string);
  Procedure ConcatLocal(p:TAsmList;const s : string);


Implementation

uses
  SysUtils,
  defutil,Systems,Verbose,Globals,
  SymTable,paramgr,
  aasmcpu,
  ProcInfo,ngenutil;

{*************************************************************************
                              TExprParse
*************************************************************************}

Constructor TExprParse.create;
Begin
end;


Procedure TExprParse.RPNPush(Num : TCGInt);
{ Add an operand to the top of the RPN stack }
begin
  if RPNTop < RPNMax then
   begin
     Inc(RPNTop);
     RPNStack[RPNTop]:=Num;
   end
  else
   Message(asmr_e_expr_illegal);
end;


Function TExprParse.RPNPop : TCGInt;
{ Get the operand at the top of the RPN stack }
begin
  RPNPop:=0;
  if RPNTop > 0 then
   begin
     RPNPop:=RPNStack[RPNTop];
     Dec(RPNTop);
   end
  else
   Message(asmr_e_expr_illegal);
end;


Procedure TExprParse.RPNCalc(const Token : String; prefix:boolean);                       { RPN Calculator }
Var
  Temp  : TCGInt;
  n1,n2 : TCGInt;
  LocalError : Integer;
begin
  { Handle operators }
  if (Length(Token) = 1) and (Token[1] in ['+', '-', '*', '/','&','|','%','^','~','<','>']) then
   Case Token[1] of
    '+' :
      Begin
        if not prefix then
         RPNPush(RPNPop + RPNPop);
      end;
    '-' :
      Begin
        if prefix then
         RPNPush(-(RPNPop))
        else
         begin
           n1:=RPNPop;
           n2:=RPNPop;
           RPNPush(n2 - n1);
         end;
      end;
    '*' : RPNPush(RPNPop * RPNPop);
    '&' :
      begin
        n1:=RPNPop;
        n2:=RPNPop;
        RPNPush(n2 and n1);
      end;
    '|' :
      begin
        n1:=RPNPop;
        n2:=RPNPop;
        RPNPush(n2 or n1);
      end;
    '~' : RPNPush(NOT RPNPop);
    '<' :
      begin
        n1:=RPNPop;
        n2:=RPNPop;
        RPNPush(n2 SHL n1);
      end;
    '>' :
      begin
        n1:=RPNPop;
        n2:=RPNPop;
        RPNPush(n2 SHR n1);
      end;
    '%' :
      begin
        Temp:=RPNPop;
        if Temp <> 0 then
         RPNPush(RPNPop mod Temp)
        else
         begin
           Message(asmr_e_expr_zero_divide);
           { push 1 for error recovery }
           RPNPush(1);
         end;
      end;
    '^' : RPNPush(RPNPop XOR RPNPop);
    '/' :
      begin
        Temp:=RPNPop;
        if Temp <> 0 then
         RPNPush(RPNPop div Temp)
        else
         begin
           Message(asmr_e_expr_zero_divide);
           { push 1 for error recovery }
           RPNPush(1);
         end;
      end;
   end
  else
   begin
     { Convert String to number and add to stack }
      Val(Token, Temp, LocalError);
     if LocalError = 0 then
      RPNPush(Temp)
     else
      begin
        Message(asmr_e_expr_illegal);
        { push 1 for error recovery }
        RPNPush(1);
      end;
   end;
end;


Procedure TExprParse.OpPush(_Operator : char;prefix: boolean);
{ Add an operator onto top of the stack }
begin
  if OpTop < OpMax then
   begin
     Inc(OpTop);
     OpStack[OpTop].ch:=_Operator;
     OpStack[OpTop].is_prefix:=prefix;
   end
  else
   Message(asmr_e_expr_illegal);
end;


Procedure TExprParse.OpPop(var _Operator:TExprOperator);
{ Get operator at the top of the stack }
begin
  if OpTop > 0 then
   begin
     _Operator:=OpStack[OpTop];
     Dec(OpTop);
   end
  else
   Message(asmr_e_expr_illegal);
end;


Function TExprParse.Priority(_Operator : Char) : aint;
{ Return priority of operator }
{ The greater the priority, the higher the precedence }
begin
  Priority:=0;
  Case _Operator OF
    '(','[' :
      Priority:=0;
    '|','^','~' :             // the lowest priority: OR, XOR, NOT
      Priority:=0;
    '&' :                     // bigger priority: AND
      Priority:=1;
    '+', '-' :                // bigger priority: +, -
      Priority:=2;
    '*', '/','%','<','>' :   // the highest priority: *, /, MOD, SHL, SHR
      Priority:=3;
    else
      Message(asmr_e_expr_illegal);
  end;
end;


Function TExprParse.Evaluate(Expr : String):TCGInt;
Var
  I     : LongInt;
  Token : String;
  opr   : TExprOperator;
begin
  Evaluate:=0;
  { Reset stacks }
  OpTop :=0;
  RPNTop:=0;
  Token :='';
  { nothing to do ? }
  if Expr='' then
   exit;
  For I:=1 to Length(Expr) DO
   begin
     if Expr[I] in ['0'..'9'] then
      begin       { Build multi-digit numbers }
        Token:=Token + Expr[I];
        if I = Length(Expr) then          { Send last one to calculator }
         RPNCalc(Token,false);
      end
     else
      if Expr[I] in ['+', '-', '*', '/', '(', ')','[',']','^','&','|','%','~','<','>'] then
       begin
         if Token <> '' then
          begin        { Send last built number to calc. }
            RPNCalc(Token,false);
            Token:='';
          end;

         Case Expr[I] OF
          '[' : OpPush('[',false);
          ']' : begin
                  While (OpTop>0) and (OpStack[OpTop].ch <> '[') DO
                   Begin
                     OpPop(opr);
                     RPNCalc(opr.ch,opr.is_prefix);
                   end;
                  OpPop(opr);                          { Pop off and ignore the '[' }
                end;
          '(' : OpPush('(',false);
          ')' : begin
                  While (OpTop>0) and (OpStack[OpTop].ch <> '(') DO
                   Begin
                     OpPop(opr);
                     RPNCalc(opr.ch,opr.is_prefix);
                   end;
                  OpPop(opr);                          { Pop off and ignore the '(' }
                end;
  '+','-','~' : Begin
                  { workaround for -2147483648 }
                  if (expr[I]='-') and (expr[i+1] in ['0'..'9']) then
                   begin
                     token:='-';
                     expr[i]:='+';
                   end;
                  { if start of expression then surely a prefix }
                  { or if previous char was also an operator    }
                  if (I = 1) or (not (Expr[I-1] in ['0'..'9',')'])) then
                    OpPush(Expr[I],true)
                  else
                    Begin
                    { Evaluate all higher priority operators }
                      While (OpTop > 0) AND (Priority(Expr[I]) <= Priority(OpStack[OpTop].ch)) DO
                       Begin
                         OpPop(opr);
                         RPNCalc(opr.ch,opr.is_prefix);
                       end;
                      OpPush(Expr[I],false);
                    End;
                end;
     '*', '/',
  '^','|','&',
  '%','<','>' : begin
                  While (OpTop > 0) and (Priority(Expr[I]) <= Priority(OpStack[OpTop].ch)) DO
                   Begin
                     OpPop(opr);
                     RPNCalc(opr.ch,opr.is_prefix);
                   end;
                  OpPush(Expr[I],false);
                end;
         end; { Case }
       end
     else
      Message(asmr_e_expr_illegal);  { Handle bad input error }
   end;

{ Pop off the remaining operators }
  While OpTop > 0 do
   Begin
     OpPop(opr);
     RPNCalc(opr.ch,opr.is_prefix);
   end;

{ The result is stored on the top of the stack }
  Evaluate:=RPNPop;
end;


Destructor TExprParse.Destroy;
Begin
end;


Function CalculateExpression(const expression: string): TCGInt;
var
  expr: TExprParse;
Begin
  expr:=TExprParse.create;
  CalculateExpression:=expr.Evaluate(expression);
  expr.Free;
  expr := nil;
end;


{*************************************************************************}
{                         String conversions/utils                        }
{*************************************************************************}

Function EscapeToPascal(const s:ShortString): ShortString;
{ converts a C styled string - which contains escape }
{ characters to a pascal style string.               }
var
  i,len : asizeint;
  hs    : ShortString;
  temp  : string;
  c     : char;
Begin
  hs:='';
  len:=0;
  i:=0;
  while (i<length(s)) and (len<255) do
   begin
     Inc(i);
     if (s[i]='\') and (i<length(s)) then
      Begin
        inc(i);
        case s[i] of
         '\' :
           c:='\';
         'b':
           c:=#8;
         'f':
           c:=#12;
         'n':
           c:=#10;
         'r':
           c:=#13;
         't':
           c:=#9;
         '"':
           c:='"';
         '0'..'7':
           Begin
             temp:=s[i];
             temp:=temp+s[i+1];
             temp:=temp+s[i+2];
             inc(i,2);
             c:=chr(ParseVal(temp,8));
           end;
         'x':
           Begin
             temp:=s[i+1];
             temp:=temp+s[i+2];
             inc(i,2);
             c:=chr(ParseVal(temp,16));
           end;
         else
           Begin
             Message1(asmr_e_escape_seq_ignored,s[i]);
             c:=s[i];
           end;
        end;
      end
     else
      c:=s[i];
     inc(len);
     hs[len]:=c;
   end;
  hs[0]:=chr(len);
  EscapeToPascal:=hs;
end;


Function ParseVal(const S:String;base:byte):TCGInt;
{ Converts a decimal string to tcgint }
var
  code : integer;
  errmsg : word;
  prefix : string[2];
Begin
  case base of
    2 :
      begin
        errmsg:=asmr_e_error_converting_binary;
        prefix:='%';
      end;
    8 :
      begin
        errmsg:=asmr_e_error_converting_octal;
        prefix:='&';
      end;
    10 :
      begin
        errmsg:=asmr_e_error_converting_decimal;
        prefix:='';
      end;
    16 :
      begin
        errmsg:=asmr_e_error_converting_hexadecimal;
        prefix:='$';
      end;
    else
      InternalError(200501202);
  end;
  val(prefix+s,result,code);
  if code<>0 then
    begin
      val(prefix+s,result,code);
      if code<>0 then
        begin
          Message1(errmsg,s);
          result:=0;
        end;
    end;
end;


Function PadZero(Var s: ShortString; n: byte): Boolean;
Begin
  PadZero:=TRUE;
  { Do some error checking first }
  if Length(s) = n then
    exit
  else
  if Length(s) > n then
  Begin
    PadZero:=FALSE;
    delete(s,n+1,length(s));
    exit;
  end
  else
    PadZero:=TRUE;
  { Fill it up with the specified character }
  fillchar(s[length(s)+1],n-1,#0);
  s[0]:=chr(n);
end;


{****************************************************************************
                                   TOperand
****************************************************************************}

constructor TOperand.Create;
begin
  size:=OS_NO;
  hasproc:=false;
  hastype:=false;
  hasvar:=false;
  FillChar(Opr,sizeof(Opr),0);
end;


destructor TOperand.Destroy;
begin
end;


Procedure TOperand.SetSize(_size:LongInt;force:boolean);
begin
  if force or
     ((size = OS_NO) and (_size<=16)) then
   Begin
     case _size of
        1 : size:=OS_8;
        2 : size:=OS_16{ could be S_IS};
        4 : size:=OS_32{ could be S_IL or S_FS};
        8 : size:=OS_64{ could be S_D or S_FL};
       10 : size:=OS_F80;
       16 : size:=OS_128;
     end;
   end;
end;


Procedure TOperand.SetCorrectSize(opcode:TAsmOp);
begin
end;


function TOperand.SetupResult:boolean;

begin
  SetupResult:=false;
  { replace by correct offset. }
  with CurrentProcInfo.procdef do
    if (not is_void(ReturnDef)) then
      begin
        SetupResult:=setupvar('result',false)
      end
    else
      message(asmr_e_void_function);
end;


Function TOperand.SetupSelf:boolean;
Begin
  SetupSelf:=false;
  if Assigned(CurrentStructDef) then
    SetupSelf:=setupvar('self',false)
  else
    Message(asmr_e_cannot_use_SELF_outside_a_method);
end;


Function TOperand.SetupOldEBP:boolean;
Begin
  SetupOldEBP:=false;
  if CurrentProcInfo.procdef.ParaST.SymTableLevel>normal_function_level then
    SetupOldEBP:=setupvar('parentframe',false)
  else
    Message(asmr_e_cannot_use_OLDEBP_outside_nested_procedure);
end;


Function TOperand.SetupVar(const s:string;GetOffset : boolean): Boolean;

  function symtable_has_localvarsyms(st:TSymTable):boolean;
  var
    sym : TSym;
    i   : LongInt;
  begin
    result:=false;
    for i:=0 to st.SymList.Count-1 do
      begin
        sym:=TSym(st.SymList[i]);
        if sym.typ=localvarsym then
          begin
            result:=true;
            exit;
          end;
      end;
  end;

  procedure setconst(l:aint);
  begin
    { We return the address of the field, just like Delphi/TP }
    case opr.typ of
      OPR_NONE :
        begin
          opr.typ:=OPR_CONSTANT;
          opr.val:=l;
        end;
      OPR_CONSTANT :
        inc(opr.val,l);
      OPR_REFERENCE :
        inc(opr.ref.offset,l);
      OPR_LOCAL :
        inc(opr.localsymofs,l);
      else
        Message(asmr_e_invalid_operand_type);
    end;
  end;


  procedure setvarsize(sym: TAbstractVarSym);
  var
    harrdef: TArrayDef;
    l: asizeint;
  begin
    case sym.vardef.typ of
      orddef,
      enumdef,
      pointerdef,
      procvardef,
      floatdef :
        SetSize(sym.GetSize,false);
      arraydef :
        begin
          { for arrays try to get the element size, take care of
            multiple indexes }
          harrdef:=TArrayDef(sym.vardef);

          { calc array size }
          if is_special_array(harrdef) then
             l := -1
           else
             l := harrdef.size;

          case opr.typ of
            OPR_REFERENCE: opr.varsize := l;
                OPR_LOCAL: opr.localvarsize := l;
            else
              ;
          end;


          while Assigned(harrdef.ElementDef) and
                (harrdef.ElementDef.typ=arraydef) do
           harrdef:=TArrayDef(harrdef.ElementDef);
          if not is_packed_array(harrdef) then
            SetSize(harrdef.EleSize,false)
           else
               if (harrdef.ElePackedBitSize mod 8) = 0 then
                 SetSize(harrdef.ElePackedBitSize div 8,false);
        end;
      recorddef:
        case opr.typ of
          OPR_REFERENCE: opr.varsize := sym.GetSize;
              OPR_LOCAL: opr.localvarsize := sym.GetSize;
          else
            ;
        end;
      else
        ;
    end;
  end;

{ search and sets up the correct fields in the Instr record }
{ for the NON-constant identifier passed to the routine.    }
{ if not found returns FALSE.                               }
var
  sym : TSym;
  srsymtable : TSymTable;
{$ifdef x86}
  segreg,
{$endif x86}
  indexreg : TRegister;
  plist : PPropAccessListItem;
  size_set_from_absolute : boolean = false;
  { offset fixup (in bytes), coming from an absolute declaration with an index
    (e.g. var tralala: word absolute moo[5]; ) }
  absoffset: asizeint=0;
  harrdef: TArrayDef;
  tmpprocinfo: TProcInfo;
Begin
  SetupVar:=false;
  asmsearchsym(s,sym,srsymtable);
  if sym = nil then
   exit;
  if sym.typ=absolutevarsym then
    begin
      case TAbsoluteVarSym(sym).AbsTyp of
        tovar:
          begin
            { Only support simple loads }
            plist:=TAbsoluteVarSym(sym).ref.FirstSym;
            if Assigned(plist) and
               (plist^.SLType=sl_load) then
              begin
                setvarsize(TAbstractVarSym(sym));
                size_set_from_absolute:=true;
                sym:=plist^.sym;
                { Check if address can be resolved, but only if not an array }
                if (sym.typ=absolutevarsym) and (TAbsoluteVarSym(sym).AbsTyp=toaddr) and not
                  (Assigned(plist^.next) and (plist^.next^.SLType=sl_vec)) then
                  begin
                    initref;
                    opr.ref.offset:=TAbsoluteVarSym(sym).AddrOffset;
                    hasvar:=true;
                    Result:=true;
                    exit;
                  end;
                { resolve the chain of array indexes (if there are any) }
                harrdef:=nil;
                while Assigned(plist^.next) do
                  begin
                    plist:=plist^.next;
                    if (plist^.SLType=sl_vec) and (TAbstractVarSym(sym).vardef.typ=arraydef) then
                      begin
                        if harrdef=nil then
                          harrdef:=TArrayDef(TAbstractVarSym(sym).vardef)
                        else if harrdef.ElementDef.typ=arraydef then
                          harrdef:=TArrayDef(harrdef.ElementDef)
                        else
                          begin
                            Message(asmr_e_unsupported_symbol_type);
                            exit;
                          end;
                        if is_special_array(harrdef) then
                          begin
                            Message(asmr_e_unsupported_symbol_type);
                            exit;
                          end;
                        if not is_packed_array(harrdef) then
                          Inc(absoffset,asizeint(Int64(plist^.value-harrdef.LowRange))*harrdef.EleSize)
                        else if (Int64(plist^.value-harrdef.LowRange)*harrdef.ElePackedBitSize mod 8)=0 then
                          Inc(absoffset,asizeint(Int64(plist^.value-harrdef.LowRange)*harrdef.ElePackedBitSize div 8))
                        else
                          Message(asmr_e_packed_element);
                      end
                    else
                      begin
                        Message(asmr_e_unsupported_symbol_type);
                        exit;
                      end;
                  end;
              end
            else
              begin
                Message(asmr_e_unsupported_symbol_type);
                exit;
              end;
          end;
        toaddr:
          begin
            initref;
            opr.ref.offset:=TAbsoluteVarSym(sym).AddrOffset;
            setvarsize(TAbstractVarSym(sym));
            size_set_from_absolute:=true;
            hasvar:=true;
            Result:=true;
            exit;
          end;
        else
          begin
            Message(asmr_e_unsupported_symbol_type);
            exit;
          end;
      end;
    end;
  case sym.typ of
    FieldVarSym :
      begin
        if not TAbstractRecordSymTable(sym.owner).Is_Packed then
          setconst(absoffset+TFieldVarSym(sym).FieldOffset)
        else if TFieldVarSym(sym).FieldOffset mod 8 = 0 then
          setconst(absoffset+TFieldVarSym(sym).FieldOffset div 8)
        else
          Message(asmr_e_packed_element);
        if not size_set_from_absolute then
          setvarsize(TAbstractVarSym(sym));
        hasvar:=true;
        SetupVar:=true;
      end;
    staticvarsym,
    localvarsym,
    paravarsym :
      begin
        { we always assume in asm statements that     }
        { that the variable is valid.                 }
        TAbstractVarSym(sym).VarState:=vs_readwritten;
        inc(TAbstractVarSym(sym).refs);
        { variable can't be placed in a register }
        TAbstractVarSym(sym).VarRegable:=vr_none;
        { and anything may happen with its address }
        TAbstractVarSym(sym).AddrTaken:=true;
        case sym.typ of
          staticvarsym :
            begin
              initref;
              opr.ref.symbol:=CurrentAsmData.RefAsmSymbol(TStaticVarSym(sym).MangledName,AT_DATA);
              Inc(opr.ref.offset,absoffset);
            end;
          paravarsym,
          localvarsym :
            begin
              tmpprocinfo:=CurrentProcInfo;
              while Assigned(tmpprocinfo) do
                begin
                  if (sym.owner=tmpprocinfo.procdef.LocalST) or
                     (sym.owner=tmpprocinfo.procdef.ParaST) then
                    begin
                      tmpprocinfo.procdef.Init_ParaLoc_Info(calleeside);
                      break;
                    end;
                  tmpprocinfo:=tmpprocinfo.parent;
                end;
              if opr.typ=OPR_REFERENCE then
                begin
{$ifdef x86}
                  segreg:=opr.ref.segment;
{$endif x86}
                  indexreg:=opr.ref.base;
                  if opr.ref.index<>NR_NO then
                    begin
                      if indexreg=NR_NO then
                        indexreg:=opr.ref.index
                      else
                        Message(asmr_e_multiple_index);
                    end;
                end
              else
                begin
{$ifdef x86}
                  segreg:=NR_NO;
{$endif x86}
                  indexreg:=NR_NO;
                end;
              opr.typ:=OPR_LOCAL;
              if Assigned(CurrentProcInfo.parent) and
                 not(po_inline in CurrentProcInfo.procdef.ProcOptions) and
                 (sym.owner<>CurrentProcInfo.procdef.LocalST) and
                 (sym.owner<>CurrentProcInfo.procdef.ParaST) and
                 (CurrentProcInfo.procdef.LocalST.SymTableLevel>normal_function_level) and
                 symtable_has_localvarsyms(CurrentProcInfo.procdef.LocalST) then
                message1(asmr_e_local_para_unreachable,s);
              opr.localsym:=TAbstractNormalVarSym(sym);
              opr.localsymofs:=absoffset;
{$ifdef x86}
              opr.localsegment:=segreg;
{$endif x86}
              opr.localindexreg:=indexreg;
              opr.localscale:=0;
              opr.localgetoffset:=GetOffset;
              if paramanager.push_addr_param(TAbstractVarSym(sym).VarSpez,TAbstractVarSym(sym).vardef,CurrentProcInfo.procdef.ProcCallOption) then
                SetSize(sizeof(PInt),false);
            end;
          else
            ;
        end;
        if not size_set_from_absolute then
          setvarsize(TAbstractVarSym(sym));
        hasvar:=true;
        SetupVar:=true;
        Exit;
      end;
    constsym :
      begin
        if TConstSym(sym).ConstTyp=constord then
         begin
           setconst(TConstSym(sym).value.ValueOrd.svalue);
           SetupVar:=true;
           Exit;
         end;
      end;
    TypeSym :
      begin
        if TTypeSym(sym).typedef.typ in [recorddef,objectdef] then
         begin
           setconst(0);
           SetupVar:=TRUE;
           Exit;
         end;
      end;
    ProcSym :
      begin
        if TProcSym(sym).ProcdefList.Count>1 then
          Message(asmr_w_calling_overload_func);
        case opr.typ of
          OPR_REFERENCE:
            begin
              opr.ref.symbol:=CurrentAsmData.RefAsmSymbol(TProcDef(TProcSym(sym).ProcdefList[0]).MangledName,AT_FUNCTION);
              Inc(opr.ref.offset,absoffset);

            end;
          OPR_NONE:
            begin
              opr.typ:=OPR_SYMBOL;
              opr.symbol:=CurrentAsmData.RefAsmSymbol(TProcDef(TProcSym(sym).ProcdefList[0]).MangledName,AT_FUNCTION);

              opr.symofs:=absoffset;
            end;
        else
          Message(asmr_e_invalid_operand_type);
        end;
        hasproc:=true;
        hasvar:=true;
        SetupVar:=TRUE;
        Exit;
      end;

    else
      begin
        Message(asmr_e_unsupported_symbol_type);
        exit;
      end;
  end;
end;


procedure TOperand.InitRef;
{*********************************************************************}
{  Description: This routine first check if the opcode is of          }
{  type OPR_NONE, or OPR_REFERENCE , if not it gives out an error.    }
{  If the operandtype = OPR_NONE or <> OPR_REFERENCE then it sets up  }
{  the operand type to OPR_REFERENCE, as well as setting up the ref   }
{  to point to the default segment.                                   }
{*********************************************************************}
var
  l : aint;
  hsymofs : aint;
  hsymbol : TAsmSymbol;
  reg : TRegister;
  hsym_farprocentry: Boolean;
Begin
  case opr.typ of
    OPR_REFERENCE :
      exit;
    OPR_CONSTANT :
      begin
        l:=opr.val;
        opr.typ:=OPR_REFERENCE;
        Fillchar(opr.ref,sizeof(TReference),0);
        opr.Ref.Offset:=l;
        opr.varsize:=0;
        opr.constoffset:=0;
        opr.ref_farproc_entry:=false;
      end;
    OPR_NONE :
      begin
        opr.typ:=OPR_REFERENCE;
        opr.varsize:=0;
        opr.constoffset:=0;
        opr.ref_farproc_entry:=false;
        Fillchar(opr.ref,sizeof(TReference),0);
      end;
    OPR_REGISTER :
      begin
        reg:=opr.reg;
        opr.typ:=OPR_REFERENCE;
        opr.varsize:=0;
        opr.constoffset:=0;
        opr.ref_farproc_entry:=false;
        Fillchar(opr.ref,sizeof(TReference),0);
        opr.Ref.base:=reg;
      end;
    OPR_SYMBOL :
      begin
        hsymbol:=opr.symbol;
        hsymofs:=opr.symofs;
        hsym_farprocentry:=opr.sym_farproc_entry;
        opr.typ:=OPR_REFERENCE;
        opr.varsize:=0;
        opr.constoffset:=0;
        Fillchar(opr.ref,sizeof(TReference),0);
        opr.ref.symbol:=hsymbol;
        opr.ref.offset:=hsymofs;
        opr.ref_farproc_entry:=hsym_farprocentry;
      end;
    else
      InitRefError;
    end;
end;

procedure TOperand.InitRefConvertLocal;
var
  localvarsize,localconstoffset: asizeint;
  localsym:TAbstractNormalVarSym;
  localsymofs:aint;
{$ifdef x86}
  localsegment,
{$endif x86}
  localindexreg:TRegister;
  localscale:byte;
begin
  if opr.typ=OPR_LOCAL then
    begin
      if AsmRegisterPara(opr.localsym) and
         not opr.localgetoffset then
        begin
          localvarsize:=opr.localvarsize;
          localconstoffset:=opr.localconstoffset;
          localsym:=opr.localsym;
          localsymofs:=opr.localsymofs;
{$ifdef x86}
          localsegment:=opr.localsegment;
{$endif x86}
          localindexreg:=opr.localindexreg;
          localscale:=opr.localscale;
          opr.typ:=OPR_REFERENCE;
          hasvar:=false;
          Fillchar(opr.ref,sizeof(TReference),0);
          opr.varsize:=localvarsize;
          opr.constoffset:=localconstoffset;
          opr.ref_farproc_entry:=false;
          opr.ref.base:=TParaVarSym(localsym).ParaLoc[calleeside].Location^.register;
          opr.ref.offset:=localsymofs;
{$ifdef x86}
          opr.ref.segment:=localsegment;
{$endif x86}
          opr.ref.index:=localindexreg;
          opr.ref.scalefactor:=localscale;
        end
      else
        InitRefError;
    end
  else
    InitRef;
end;

procedure TOperand.InitRefError;
begin
  Message(asmr_e_invalid_operand_type);
  { Recover }
  opr.typ:=OPR_REFERENCE;
  opr.varsize:=0;
  opr.constoffset:=0;
  opr.ref_farproc_entry:=false;
  Fillchar(opr.ref,sizeof(TReference),0);
end;

Function TOperand.CheckOperand(ins : TInstruction): boolean;
{*********************************************************************}
{  Description: This routine checks if the operand is of              }
{  valid, and returns false if it isn't. Does nothing by default.     }
{*********************************************************************}
begin
  result:=true;
end;


{****************************************************************************
                                 TInstruction
****************************************************************************}

constructor TInstruction.create(optype : TCOperand);
  var
    i : LongInt;
  Begin
    { these field are set to 0 anyways by the constructor helper (FK)
    Opcode:=A_NONE;
    Condition:=C_NONE;
    Ops:=0;
    }
    filepos:=CurrentFilePos;
    for i:=1 to max_operands do
      Operands[i]:=optype.create;
    Labeled:=false;
  end;


destructor TInstruction.Destroy;
var
  i : LongInt;
Begin
  for i:=1 to max_operands do
   FreeAndNil(Operands[i]);
end;


  function TInstruction.ConcatInstruction(p:TAsmList) : TAI;
    var
      ai   : TAICPU;
      i : LongInt;
    begin
      for i:=1 to Ops do
        operands[i].CheckOperand(self);

      ai:=TAICPU.op_none(opcode);
      ai.fileinfo:=filepos;
      ai.Ops:=Ops;
      ai.Allocate_oper(Ops);
      for i:=1 to Ops do
        with operands[i].opr do
          begin
            case typ of
              OPR_CONSTANT :
                ai.loadconst(i-1,val);
              OPR_REGISTER:
                ai.loadreg(i-1,reg);
              OPR_SYMBOL:
                ai.loadsymbol(i-1,symbol,symofs);
              OPR_LOCAL :
                begin
                  ai.loadlocal(i-1,localsym,localsymofs,localindexreg,
                               localscale,localgetoffset,localforceref);
{$ifdef x86}
                  ai.oper[i-1]^.localoper^.localsegment:=localsegment;
{$endif x86}
                end;
              OPR_REFERENCE:
                ai.loadref(i-1,ref);
{$if defined(aarch64)}
             OPR_SHIFTEROP:
               ai.loadshifterop(i-1,shifterop);
             OPR_COND:
               ai.loadconditioncode(i-1,cc);
{$endif}
{$ifdef aarch64}
              OPR_REGSET:
                ai.loadregset(i-1,basereg,nregs,regsetindex);
              OPR_INDEXEDREG:
                ai.loadindexedreg(i-1,indexedreg,regindex);
{$endif aarch64}
              { ignore wrong operand }
              OPR_NONE:
                ;
              else
                InternalError(200501051);
            end;
          end;
     ai.SetCondition(condition);
     { Concat the opcode or give an error }
      if Assigned(ai) then
         p.concat(ai)
      else
       Message(asmr_e_invalid_opcode_and_operand);
      result:=ai;
    end;


{****************************************************************************
                      Symbol table helper routines
****************************************************************************}

procedure AddAbsoluteSymRefs(sym: TAbsoluteVarSym); forward;

procedure MaybeAddSymRef(sym: TSym);
begin
  case sym.typ of
     absolutevarsym:
       AddAbsoluteSymRefs(TAbsoluteVarSym(sym));
     staticvarsym:
       if not(vo_is_external in TStaticVarSym(sym).VarOptions) then
         CNodeUtils.RegisterUsedAsmSym(CurrentAsmData.RefAsmSymbol(sym.MangledName,AT_DATA),TStaticVarSym(sym).vardef,true);
     ProcSym:
       begin
         { if it's a pure assembler routine, the definition of the symbol will also
           be in assembler and it can't be removed by the compiler (and if we mark
           it as used anyway, clang will get into trouble) }
         if not(po_assembler in TProcDef(TProcSym(sym).ProcdefList[0]).ProcOptions) and
            not(po_external in TProcDef(TProcSym(sym).ProcdefList[0]).ProcOptions) then
           CNodeUtils.RegisterUsedAsmSym(CurrentAsmData.RefAsmSymbol(TProcDef(TProcSym(sym).ProcdefList[0]).MangledName,AT_FUNCTION),TProcDef(TProcSym(sym).ProcdefList[0]),true);
       end;
     else
       ;
   end;
end;

procedure AddAbsoluteSymRefs(sym: TAbsoluteVarSym);
var
  SymList: PPropAccessListItem;
begin
  case sym.AbsTyp of
    toaddr:
      ;
    toasm:
      begin
        CNodeUtils.RegisterUsedAsmSym(CurrentAsmData.RefAsmSymbol(sym.MangledName,AT_DATA),sym.vardef,true);
      end;
    tovar:
      begin
        SymList:=TAbsoluteVarSym(sym).ref.FirstSym;
        repeat
          case SymList^.SLType of
            sl_load:
              MaybeAddSymRef(SymList^.sym);
            sl_subscript,
            sl_absolutetype,
            sl_typeconv,
            sl_vec:
              ;
            else
              InternalError(2009031401);
          end;
          SymList:=SymList^.next;
        until not Assigned(SymList);
      end;
  end;
end;

procedure AsmSearchSym(const s:string;out srsym:TSym;out srsymtable:TSymTable);
var
  i : integer;
begin
  i:=pos('.',s);
  { allow unit.identifier }
  if i>1 then
    begin
      SearchSym(Copy(s,1,i-1),srsym,srsymtable);
      if Assigned(srsym) then
       begin
         if (srsym.typ=UnitSym) and
            (srsym.owner.SymTableType in [staticsymtable,GlobalSymTable]) and
            srsym.owner.IsCurrentUnit then
           SearchSym_In_Module(TUnitSym(srsym).module,Copy(s,i+1,255),srsym,srsymtable)
         else
           begin
             srsym:=nil;
             srsymtable:=nil;
           end;
       end;
    end
  else
    SearchSym(s,srsym,srsymtable);
  { in asm routines, the function result variable, that matches the function
    name should be avoided, because:
    1) there's already a @Result directive (even in TP7) that can be used, if
       you want to access the function result
    2) there's no other way to disambiguate between the function result variable
       and the function's address (using asm syntax only)

    This fixes code, such as:

    function test1: word;
    begin
      asm
        mov ax, offset test1
      end;
    end;

    and makes it work in a consistent manner as this code:

    procedure test2;
    begin
      asm
        mov ax, offset test2
      end;
    end; }
  if Assigned(srsym) and
     Assigned(srsymtable) and
     (srsym.typ=absolutevarsym) and
     (vo_is_funcret in TAbsoluteVarSym(srsym).VarOptions) and
     (srsymtable.SymTableType=LocalSymTable) and
     Assigned(srsymtable.DefOwner) and
     (srsymtable.DefOwner.typ=procdef) and
     (TProcDef(srsymtable.DefOwner).ProcSym.name=TAbsoluteVarSym(srsym).Name) then
    begin
      srsym:=TProcDef(srsymtable.DefOwner).ProcSym;
      srsymtable:=srsym.Owner;
    end;
  { llvm can't catch symbol references from inline assembler blocks }
  if Assigned(srsym) then
    MaybeAddSymRef(srsym);
end;


Function SearchType(const hs:string;out size:TCGInt): Boolean;
var
  srsym : TSym;
  srsymtable : TSymTable;
begin
  result:=false;
  size:=0;
  asmsearchsym(hs,srsym,srsymtable);
  if Assigned(srsym) and
     (srsym.typ=TypeSym) then
    begin
      size:=TTypeSym(srsym).typedef.size;
      result:=true;
    end;
end;



Function SearchRecordType(const s:string): boolean;
var
  srsym : TSym;
  srsymtable : TSymTable;
Begin
  SearchRecordType:=false;
{ Check the constants in symtable }
  asmsearchsym(s,srsym,srsymtable);
  if srsym <> nil then
   Begin
     case srsym.typ of
       TypeSym :
         begin
           if TTypeSym(srsym).typedef.typ in [recorddef,objectdef] then
            begin
              SearchRecordType:=true;
              exit;
            end;
         end;
       FieldVarSym :
         begin
           if (TFieldVarSym(srsym).vardef.typ in [recorddef,objectdef]) then
             begin
               SearchRecordType:=true;
               exit;
             end;
         end;
       else
         ;
     end;
   end;
end;


Function SearchIConstant(const s:string; var l:TCGInt): boolean;
{**********************************************************************}
{  Description: Searches for a CONSTANT of name s in either the local  }
{  symbol list, then in the global symbol list, and returns the value  }
{  of that constant in l. Returns TRUE if successfull, if not found,   }
{  or if the constant is not of correct type, then returns FALSE       }
{ Remarks: Also handle TRUE and FALSE returning in those cases 1 and 0 }
{  respectively.                                                       }
{**********************************************************************}
var
  srsym : TSym;
  srsymtable : TSymTable;
Begin
  SearchIConstant:=false;
{ check for TRUE or FALSE reserved words first }
  if s = 'TRUE' then
   Begin
     SearchIConstant:=TRUE;
     l:=1;
     exit;
   end;
  if s = 'FALSE' then
   Begin
     SearchIConstant:=TRUE;
     l:=0;
     exit;
   end;
{ Check the constants in symtable }
  asmsearchsym(s,srsym,srsymtable);
  if srsym <> nil then
   Begin
     case srsym.typ of
       constsym :
         begin
           if TConstSym(srsym).ConstTyp=constord then
            Begin
              l:=TConstSym(srsym).value.ValueOrd.svalue;
              SearchIConstant:=TRUE;
              exit;
            end;
         end;
       enumsym:
         Begin
           l:=TEnumSym(srsym).value;
           SearchIConstant:=TRUE;
           exit;
         end;
       else
         ;
     end;
   end;
end;


function AsmRegisterPara(sym: TAbstractNormalVarSym): boolean;
begin
  result:=
    (po_assembler in CurrentProcInfo.procdef.ProcOptions) and
    (sym.typ=paravarsym) and
    (TParaVarSym(sym).ParaLoc[calleeside].Location^.Loc=LOC_REGISTER);
end;


Function GetRecordOffsetSize(s:string;out Offset: TCGInt;out Size:TCGInt; out MangledName: string; needvmtofs: boolean; out hastypecast: boolean):boolean;
{ search and returns the offset and size of records/objects of the base }
{ with field name setup in field.                              }
{ returns FALSE if not found.                                  }
{ used when base is a variable or a typed constant name.       }
var
  st   : TSymTable;
  harrdef : TArrayDef;
  sym  : TSym;
  srsymtable : TSymTable;
  i    : LongInt;
  base : string;
  procdef: TProcDef;
Begin
  GetRecordOffsetSize:=FALSE;
  Offset:=0;
  Size:=0;
  MangledName:='';
  hastypecast:=false;
  i:=pos('.',s);
  if i=0 then
   i:=255;
  base:=Copy(s,1,i-1);
  delete(s,1,i);
  if base='SELF' then
   st:=CurrentStructDef.SymTable
  else
   begin
     asmsearchsym(base,sym,srsymtable);
     { allow unitname.identifier }
     if Assigned(sym) and (sym.typ=UnitSym) then
       begin
         i:=pos('.',s);
         if i=0 then
          i:=255;
         base:=base+'.'+Copy(s,1,i-1);
         delete(s,1,i);
         asmsearchsym(base,sym,srsymtable);
       end;
     st:=nil;
     { we can start with a var,type,typedconst }
     if Assigned(sym) then
       case sym.typ of
         staticvarsym,
         localvarsym,
         paravarsym :
           st:=TAbstractVarSym(sym).vardef.GetSymTable(gs_record);
         TypeSym :
           st:=TTypeSym(sym).typedef.GetSymTable(gs_record);
         else
           ;
       end
     else
       s:='';
   end;
  { now walk all recordsymtables }
  while Assigned(st) and (s<>'') do
   begin
     { load next field in base }
     i:=pos('.',s);
     if i=0 then
      i:=255;
     base:=Copy(s,1,i-1);
     delete(s,1,i);
     sym:=Search_Struct_Member(TAbstractRecordDef(st.DefOwner),base);
     if not Assigned(sym) then
      begin
        Message(asmr_e_unknown_field);
        GetRecordOffsetSize:=false;
        exit;
      end;
     st:=nil;
     case sym.typ of
       FieldVarSym :
         with TFieldVarSym(sym) do
           begin
             if not TAbstractRecordSymTable(sym.owner).Is_Packed then
               inc(Offset,FieldOffset)
             else if TFieldVarSym(sym).FieldOffset mod 8 = 0 then
               inc(Offset,FieldOffset div 8)
             else
               Message(asmr_e_packed_element);
             size:=GetSize;
             case vardef.typ of
               arraydef :
                 begin
                   { for arrays try to get the element size, take care of
                     multiple indexes }
                   harrdef:=TArrayDef(vardef);
                   while Assigned(harrdef.ElementDef) and
                         (harrdef.ElementDef.typ=arraydef) do
                    harrdef:=TArrayDef(harrdef.ElementDef);
                   if not is_packed_array(harrdef) then
                     size:=harrdef.EleSize
                   else
                     begin
                       if (harrdef.ElePackedBitSize mod 8) <> 0 then
                         Message(asmr_e_packed_element);
                       size := (harrdef.ElePackedBitSize + 7) div 8;
                     end;
                 end;
               recorddef :
                 st:=TRecordDef(vardef).SymTable;
               objectdef :
                 st:=TObjectDef(vardef).SymTable;
               else
                 ;
             end;
           end;
       ProcSym:
         begin
           st:=nil;
           if TProcSym(sym).ProcdefList.Count>1 then
             Message(asmr_w_calling_overload_func);
           procdef:=TProcDef(TProcSym(sym).ProcdefList[0]);
           if (not needvmtofs) then
             begin
               MangledName:=procdef.MangledName;
             end
           else
             begin
               { can only get the vmtoffset of virtual methods }
               if not(po_virtualmethod in procdef.ProcOptions) or
                   Is_ObjectPascal_Helper(procdef.struct) then
                 Message1(asmr_e_no_vmtoffset_possible,FullTypeName(procdef,nil))
               else
                 begin
                   { size = sizeof(target_system_pointer) }
                   size:=sizeof(PInt);
                   offset:=TObjectDef(procdef.struct).VMTMethodOffset(procdef.ExtNumber)
                 end;
             end;
           { if something comes after the procsym, it's invalid assembler syntax }
           GetRecordOffsetSize:=(s='');
           exit;
         end;
       else
         ;
     end;
   end;
   { Support Field.Type as typecasting }
   if (st=nil) and (s<>'') then
     begin
       asmsearchsym(s,sym,srsymtable);
       if Assigned(sym) and (sym.typ=TypeSym) then
         begin
           size:=TTypeSym(sym).typedef.size;
           s:='';
           hastypecast:=true;
         end;
     end;
   GetRecordOffsetSize:=(s='');
end;


Function SearchLabel(const s: string; var hl: TAsmLabel;emit:boolean): boolean;
var
  sym : TSym;
  srsymtable : TSymTable;
  hs  : string;
Begin
  hl:=nil;
  SearchLabel:=false;
{ Check for pascal labels, which are case insensetive }
  hs:=upper(s);
  asmsearchsym(hs,sym,srsymtable);
  if sym=nil then
   exit;
  case sym.typ of
    labelsym :
      begin
        if SymTableStack.top.SymTableLevel<>srsymtable.SymTableLevel then
          begin

	    { LLVM compiler requires that the static label RawThunkEnd
             in packages/rtl-objpas/src/rtti.pas unit is set to nonlocal }
            if (srsymtable.SymTableType=GlobalSymTable) or create_smartlink_library then

              TLabelSym(sym).nonlocal:=true;
            if emit then
              include(CurrentProcInfo.flags,pi_has_interproclabel);
          end;
        if not(Assigned(TLabelSym(sym).AsmBlockLabel)) then
          if TLabelSym(sym).nonlocal then
            CurrentAsmData.getglobaljumplabel(TLabelSym(sym).AsmBlockLabel)
          else
            CurrentAsmData.getjumplabel(TLabelSym(sym).AsmBlockLabel);
        hl:=TLabelSym(sym).AsmBlockLabel;
        if emit then
          begin
            if TLabelSym(sym).defined then
              Message(sym_e_label_already_defined);
            TLabelSym(sym).defined:=true;
            hl.defined_in_asmstatement:=true
          end
        else
          TLabelSym(sym).used:=true;
        SearchLabel:=true;
      end;
    else
      ;
  end;
end;


 {*************************************************************************}
 {                   Instruction Generation Utilities                      }
 {*************************************************************************}


   Procedure ConcatString(p : TAsmList;s:string);
  {*********************************************************************}
  { PROCEDURE ConcatString(s:string);                                   }
  {  Description: This routine adds the character chain pointed to in   }
  {  s to the instruction linked list.                                  }
  {*********************************************************************}
  Begin
     p.concat(TAIString.Create(s));
  end;


Procedure ConcatConstant(p: TAsmList; value: TCGInt; constsize:byte);
{*********************************************************************}
{  Description: This routine adds the value constant to the current   }
{  instruction linked list.                                           }
{*********************************************************************}
var
  rangelo,rangehi : int64;
Begin
  case constsize of
    1 :
      begin
        p.concat(TAIConst.Create_8bit(byte(value)));
        rangelo:=low(shortint);
        rangehi:=high(byte);
      end;
    2 :
      begin
        p.concat(TAIConst.Create_16bit(word(value)));
        rangelo:=low(smallint);
        rangehi:=high(word);
      end;
    4 :
      begin
        p.concat(TAIConst.Create_32bit(LongInt(value)));
        rangelo:=low(LongInt);
        rangehi:=high(cardinal);
      end;
    8 :
      begin
        p.concat(TAIConst.Create_64bit(int64(value)));
        rangelo:=0;
        rangehi:=0;
      end;
    else
      InternalError(200405011);
  end;
  { check for out of bounds }
  if (rangelo<>0) and
     ((value>rangehi) or (value<rangelo)) then
    Message(asmr_e_constant_out_of_bounds);
end;


  Procedure ConcatConstSymbol(p : TAsmList;const sym,endsym:string;symtyp:TAsmsymtype;l:TCGInt;constsize:byte;isofs:boolean);
  begin

    p.concat(TAIConst.Createname(sym,l));

  end;


  Procedure ConcatRealConstant(p : TAsmList;value: BestReal; real_typ : TFloatType);
  {***********************************************************************}
  { PROCEDURE ConcatRealConstant(value: bestreal; real_typ : tfloattype); }
  {  Description: This routine adds the value constant to the current     }
  {  instruction linked list.                                             }
  {   real_typ -> indicates the type of the real data to initialize:      }
  {                  s32real -> create a single node.                     }
  {                  s64real -> create a double node.                     }
  {                  s80real -> create an extended node.                  }
  {                  s64bit ->  create a  comp node.                      }
  {                  f32bit ->  create a  fixed node. (not used normally) }
  {***********************************************************************}
    Begin
       case real_typ of
          S32Real : p.concat(TAIRealConst.create_s32real(Single(value)));
          S64Real :
             p.concat(TAIRealConst.create_s64real(Double(value)));
          s80real : p.concat(TAIRealConst.create_s80real(value,S80FloatType.size));
          sc80real : p.concat(TAIRealConst.create_s80real(value,SC80FloatType.size));
          s64comp : p.concat(TAIRealConst.create_s64compreal(Trunc(value)));
          else
            InternalError(2014050608);
       end;
    end;

   Procedure ConcatLabel(p: TAsmList;var l : TAsmLabel);
  {*********************************************************************}
  { PROCEDURE ConcatLabel                                               }
  {  Description: This routine either emits a label or a labeled        }
  {  instruction to the linked list of instructions.                    }
  {*********************************************************************}
   begin
     p.concat(TAILabel.Create(l));
   end;

   procedure ConcatAlign(p:TAsmList;l:TCGInt);
  {*********************************************************************}
  { PROCEDURE ConcatPublic                                              }
  {  Description: This routine emits an global   definition to the      }
  {  linked list of instructions.(used by AT&T styled asm)              }
  {*********************************************************************}
   begin
     p.concat(TAIAlign.Create(l));
   end;

   procedure ConcatPublic(p:TAsmList;const s : string);
  {*********************************************************************}
  { PROCEDURE ConcatPublic                                              }
  {  Description: This routine emits an global   definition to the      }
  {  linked list of instructions.(used by AT&T styled asm)              }
  {*********************************************************************}
   begin
       p.concat(TAISymbol.Createname_global(s,AT_LABEL,0,VoidCodePointerType));
   end;

   procedure ConcatLocal(p:TAsmList;const s : string);
  {*********************************************************************}
  { PROCEDURE ConcatLocal                                               }
  {  Description: This routine emits an local    definition to the      }
  {  linked list of instructions.                                       }
  {*********************************************************************}
   begin
       p.concat(TAISymbol.Createname(s,AT_LABEL,0,VoidCodePointerType));
   end;


end.
