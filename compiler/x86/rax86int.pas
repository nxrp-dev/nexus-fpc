{
    Copyright (c) 1998-2002 by Carl Eric Codere and Peter Vreman

    Does the parsing process for the intel styled inline assembler.

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
Unit Rax86int;

{$i fpcdefs.inc}

  interface

    uses
      CClasses,
      cpubase,
      GlobType,
      aasmbase,
      cgbase,
      rasm,
      rax86;

  type
    TAsmToken = (
      AS_NONE,AS_LABEL,AS_LLABEL,AS_STRING,AS_INTNUM,
      AS_COMMA,AS_LBRACKET,AS_RBRACKET,AS_LPAREN,
      AS_RPAREN,AS_COLON,AS_DOT,AS_PLUS,AS_MINUS,AS_STAR,
      AS_SEPARATOR,AS_ID,AS_REGISTER,AS_OPCODE,AS_SLASH,
      AS_LOPMASK,AS_VOPMASK,AS_LOPZEROMASK,AS_VOPZEROMASK,AS_LOPBCST,AS_OPBCST1TO2,AS_OPBCST1TO4,AS_OPBCST1TO8,AS_OPBCST1TO16,AS_OPBCST1TO32,AS_LOPSAE,AS_OPSAE,
      AS_LOPER,AS_OPRNSAE,AS_OPRDSAE,AS_OPRUSAE,AS_OPRZSAE,
       {------------------ Assembler directives --------------------}
      AS_ALIGN,AS_DB,AS_DW,AS_DD,AS_DQ,AS_PUBLIC,AS_END,
       {------------------ Assembler Operators  --------------------}
      AS_BYTE,AS_WORD,AS_DWORD,AS_QWORD,AS_TBYTE,AS_DQWORD,AS_OWORD,AS_XMMWORD,AS_YWORD,AS_YMMWORD,AS_ZWORD,AS_ZMMWORD,AS_NEAR,AS_FAR,
      AS_HIGH,AS_LOW,AS_OFFSET,AS_SIZEOF,AS_VMTOFFSET,AS_SEG,AS_TYPE,AS_PTR,AS_MOD,AS_SHL,AS_SHR,AS_NOT,
      AS_AND,AS_OR,AS_XOR,AS_WRT,AS___GOTPCREL,AS_TARGET_DIRECTIVE,AS_RNSAE

      );



    type
       { input flags for BuildConstSymbolExpression }
       TConstSymbolExpressionInputFlag = (
         cseif_needofs,
         cseif_isref,
         cseif_startingminus,
         { allows using full reference-like syntax for constsymbol expressions,
           for example:
           Rec.Str[5]  ->  Rec.Str+5 }
         cseif_referencelike
       );
       TConstSymbolExpressionInputFlags = set of TConstSymbolExpressionInputFlag;
       { output flags for BuildConstSymbolExpression }
       TConstSymbolExpressionOutputFlag = (
         cseof_isseg,
         cseof_is_farproc_entry,
         cseof_hasofs
       );
       TConstSymbolExpressionOutputFlags = set of TConstSymbolExpressionOutputFlag;

       { tx86intreader }

       TX86IntReader = class(TAsmReader)
         actasmpattern_origcase : string;
         actasmtoken : TAsmToken;
         actoperextention: string;
         prevasmtoken : TAsmToken;
         ActOpsize : TOpSize;
         inexpression : boolean;
         constructor create;override;
         function is_asmopcode(const s: string):boolean;
         function is_asmoperator(const s: string):boolean;
         function is_asmdirective(const s: string):boolean;
         function is_register(const s:string):boolean;
         function is_locallabel(const s:string):boolean;
         function Assemble: TLinkedList;override;
         procedure GetToken(check_operand_extention: boolean = false);
         function consume(t : TAsmToken; check_operand_extention: boolean = false):boolean;
         //procedure ConsumeOperExtention(oper: tx86operand; const aOperExtention: string);
         procedure RecoverConsume(allowcomma:boolean);
         procedure AddReferences(dest,src : tx86operand);
         procedure SetSegmentOverride(oper:tx86operand;seg:TRegister);
         procedure BuildRecordOffsetSize(const expr: string;out offset:TCGInt;out size:TCGInt; out MangledName: string; needvmtofs: boolean; out hastypecast: boolean);
         procedure BuildConstSymbolExpression(in_flags: TConstSymbolExpressionInputFlags;out value:TCGInt;out asmsym:string;out asmsymtyp:TAsmsymtype;out size:TCGInt;out out_flags:TConstSymbolExpressionOutputFlags);
         function BuildConstExpression:aint;
         function BuildRefConstExpression(out size:TCGInt;startingminus:boolean=false):aint;
         procedure BuildReference(oper : tx86operand);
         procedure BuildOperand(oper: tx86operand;istypecast:boolean);
         procedure BuildConstantOperand(oper: tx86operand);
         procedure BuildOpCode(instr : tx86instruction);
         procedure BuildConstant(constsize: byte);
         procedure consume_voperand_ext(aop: tx86operand; aConsumeVOpExt: boolean = true);


         function is_targetdirective(const s: string): boolean;virtual;
         procedure HandleTargetDirective;virtual;
       end;


  implementation

    uses
       { common }
       CUtils,
       { global }
       Globals,Verbose,
       Systems,
       { aasm }
       AAsmData,aasmcpu,

       { symtable }
       symconst,SymBase,symtype,SymSym,symutil,symdef,

       { parser }
       Scanner,pbase,
       { register allocator }
       rautils,itx86int,
       { codegen }
       ProcInfo,paramgr
       ;

    type
      TAsmKeyword = string[9];


    const
       { These tokens should be modified accordingly to the modifications }
       { in the different enumerations.                                   }
       firstdirective = AS_ALIGN;
       lastdirective  = AS_END;
       firstoperator  = AS_BYTE;
       lastoperator   = AS___GOTPCREL;

       OPEXT_STARTASMTOKEN: set of TAsmToken = [AS_LOPMASK,AS_LOPZEROMASK,AS_LOPBCST,AS_LOPSAE,AS_LOPER];

       _asmdirectives : array[firstdirective..lastdirective] of TAsmKeyword =
       ('ALIGN','DB','DW','DD','DQ','PUBLIC','END');

       { problems with shl,shr,not,and,or and xor, they are }
       { context sensitive.                                 }
       _asmoperators : array[firstoperator..lastoperator] of TAsmKeyword = (
        'BYTE','WORD','DWORD','QWORD','TBYTE','DQWORD','OWORD','XMMWORD','YWORD','YMMWORD','ZWORD','ZMMWORD','NEAR','FAR','HIGH',
        'LOW','OFFSET','SIZEOF','VMTOFFSET','SEG','TYPE','PTR','MOD','SHL','SHR','NOT','AND',
        'OR','XOR','WRT','GOTPCREL');

      high_priority_tokens: set of TAsmToken = [AS_STAR,AS_SLASH,AS_MOD,AS_SHL,AS_SHR,AS_NOT,AS_AND,AS_OR,AS_XOR];

      token2str : array[TAsmToken] of string[10] = (
        '','Label','LLabel','String','Integer',
        ',','[',']','(',
        ')',':','.','+','-','*',
        ';','identifier','register','opcode','/',
        '','','','','','','','','','','','',
        '','','','','',
        '','','','','','','END',
        '','','','','','','','','','','','','','',
        '','','','sizeof','vmtoffset','','type','ptr','mod','shl','shr','not',
        'and','or','xor','wrt','..gotpcrel','','{RN-SAE}'
      );

    constructor TX86IntReader.create;
      var
        i : TAsmOp;
      Begin
        inherited create;
        iasmops:=TFPHashList.create;
        for i:=firstop to lastop do
          iasmops.Add(upper(std_op2str[i]),Pointer(PtrInt(i)));

        actoperextention := '';
      end;


{---------------------------------------------------------------------}
{                     Routines for the tokenizing                     }
{---------------------------------------------------------------------}


     function TX86IntReader.is_asmopcode(const s: string):boolean;
       var
         cond : string[4];
         cnd : TAsmCond;
         j: LongInt;
       Begin
         is_asmopcode:=FALSE;

         actopcode:=A_None;
         actcondition:=C_None;
         actopsize:=S_NO;

         { Search opcodes }
         actopcode:=TAsmOp(PtrUInt(iasmops.Find(s)));
	 { We need to exclude opcodes that require a condition suffix }
         if (actopcode<>A_NONE) and (actopcode<>A_Jcc) and
	    (actopcode<>A_SETcc) and (actopcode<>A_CMOVcc) then
           begin
             actasmtoken:=AS_OPCODE;
             result:=TRUE;
             exit;
           end;

         { not found yet, check condition opcodes }
         j:=0;
         while (j<CondAsmOps) do
          begin
            if Copy(s,1,Length(CondAsmOpStr[j]))=CondAsmOpStr[j] then
             begin
               cond:=Copy(s,Length(CondAsmOpStr[j])+1,255);
               if cond<>'' then
                begin
                  for cnd:=low(TAsmCond) to high(TAsmCond) do
                   if Cond=Upper(cond2str[cnd]) then
                    begin
                      actopcode:=CondASmOp[j];
                      actcondition:=cnd;
                      is_asmopcode:=TRUE;
                      actasmtoken:=AS_OPCODE;
                      exit
                    end;
                end;
             end;
            inc(j);
          end;
       end;


    function TX86IntReader.is_asmoperator(const s: string):boolean;
      var
        i : TAsmToken;
      Begin
        for i:=firstoperator to lastoperator do
         if s=_asmoperators[i] then
          begin
            actasmtoken:=i;
            is_asmoperator:=true;
            exit;
          end;
        is_asmoperator:=false;
      end;


    Function TX86IntReader.is_asmdirective(const s: string):boolean;
      var
        i : TAsmToken;
      Begin
        for i:=firstdirective to lastdirective do
         if s=_asmdirectives[i] then
          begin
            actasmtoken:=i;
            is_asmdirective:=true;
            exit;
          end;
        is_asmdirective:=false;
      end;


    function TX86IntReader.is_register(const s:string):boolean;
      begin
        is_register:=false;
        actasmregister:=masm_regnum_search(lower(s));
        { don't accept "flags" as register name in an instruction }
        if (GetSupReg(actasmregister)=RS_DEFAULTFLAGS) and (GetRegType(actasmregister)=GetRegType(NR_DEFAULTFLAGS)) then
          actasmregister:=NR_NO;
        if actasmregister<>NR_NO then
          begin
            is_register:=true;
            actasmtoken:=AS_REGISTER;
          end;
      end;


    function TX86IntReader.is_locallabel(const s:string):boolean;
      begin
        is_locallabel:=(length(s)>1) and (s[1]='@');
      end;


    function TX86IntReader.is_targetdirective(const s: string): boolean;
      begin
        result:=false;
      end;


    procedure TX86IntReader.handletargetdirective;
      begin
      end;


    Procedure TX86IntReader.GetToken(check_operand_extention: boolean);
      var
        len : LongInt;
        forcelabel : boolean;
        srsym : TSym;
        srsymtable : TSymTable;
      begin
        actoperextention := '';

        c:=CurrentScanner.c;
        { save old token and reset new token }
        prevasmtoken:=actasmtoken;
        actasmtoken:=AS_NONE;
        { reset }
        forcelabel:=FALSE;
        actasmpattern:='';
        { while space and tab , continue scan... }
        while (c in [' ',#9]) do
          c:=CurrentScanner.asmgetchar;
        { get token pos }
        if not (c in [#10,#13,'{',';','(','/']) then
          CurrentScanner.gettokenpos;
      { Local Label, Label, Directive, Prefix or Opcode }
        if firsttoken and not (c in [#10,#13,'{',';','(','/']) then
         begin
           firsttoken:=FALSE;
           len:=0;

           { directive check }
           if c = '.' then
            begin
              actasmpattern:='.';
              c:=CurrentScanner.asmgetchar;
              while c in ['A'..'Z','a'..'z','0'..'9','_'] do
                begin
                 actasmpattern:=actasmpattern+c;
                 c:=CurrentScanner.asmgetchar;
                end;
              { directives are case sensitive!! }
              if is_asmdirective(actasmpattern) then
               exit;
              if is_targetdirective(actasmpattern) then
                begin
                  actasmtoken:=AS_TARGET_DIRECTIVE;
                  exit;
                end;
              Message1(asmr_e_not_directive_or_local_symbol,actasmpattern);
              exit;
            end;

           while (c in ['A'..'Z','a'..'z','0'..'9','_','@']) or
                 { TP7 also allows $&? characters in local labels }
                 (forcelabel and (c in ['$','&','?'])) do
            begin
              { if there is an at_sign, then this must absolutely be a label }
              if c = '@' then
               forcelabel:=TRUE;
              inc(len);
              actasmpattern[len]:=c;
              c:=CurrentScanner.asmgetchar;
            end;
           actasmpattern[0]:=chr(len);
           actasmpattern_origcase:=actasmpattern;
           UpperVar(actasmpattern);
           { allow spaces }
           while (c in [' ',#9]) do
             c:=CurrentScanner.asmgetchar;
           { label ? }
           if c = ':' then
            begin
              if actasmpattern[1]='@' then
                actasmtoken:=AS_LLABEL
              else
                actasmtoken:=AS_LABEL;
              { let us point to the next character }
              c:=CurrentScanner.asmgetchar;
              firsttoken:=true;
              exit;
            end;
           { Are we trying to create an identifier with }
           { an at-sign...?                             }
           if forcelabel then
            Message(asmr_e_none_label_contain_at);
           { opcode ? }
           If is_asmopcode(actasmpattern) then
            Begin
              { check if we are in an expression  }
              { then continue with asm directives }
              if not inexpression then
               exit;
            end;
           if is_asmdirective(actasmpattern) then
            exit;
           message1(asmr_e_unknown_opcode,actasmpattern);
           actasmtoken:=AS_NONE;
           exit;
         end
        else { else firsttoken }
         begin
           case c of
             '@' : { possibilities : - local label reference , such as in jmp @local1}
                   {                - @Result, @Code or @Data special variables.     }
               begin
                 actasmpattern:=c;
                 c:=CurrentScanner.asmgetchar;
                 while c in  ['A'..'Z','a'..'z','0'..'9','_','@','$','&','?'] do
                  begin
                    actasmpattern:=actasmpattern + c;
                    c:=CurrentScanner.asmgetchar;
                  end;
                 actasmpattern_origcase:=actasmpattern;
                 UpperVar(actasmpattern);
                 actasmtoken:=AS_ID;
                 exit;
               end;

             'A'..'Z','a'..'z','_': { identifier, register, opcode, prefix or directive }
               begin
                 actasmpattern:=c;
                 c:=CurrentScanner.asmgetchar;
                 while c in  ['A'..'Z','a'..'z','0'..'9','_'] do
                  begin
                    actasmpattern:=actasmpattern + c;
                    c:=CurrentScanner.asmgetchar;
                  end;
                 actasmpattern_origcase:=actasmpattern;
                 UpperVar(actasmpattern);
                 { after prefix (or segment override) we allow also a new opcode }
                 If (is_prefix(actopcode) or is_override(actopcode)) and is_asmopcode(actasmpattern) then
                  Begin
                    { if we are not in a constant }
                    { expression than this is an  }
                    { opcode.                     }
                    if not inexpression then
                     exit;
                  end;
                 { support st(X) for fpu registers }
                 if (actasmpattern = 'ST') and (c='(') then
                  Begin
                    actasmpattern:=actasmpattern+c;
                    c:=CurrentScanner.asmgetchar;
                    { allow spaces }
                    while (c in [' ',#9]) do
                      c:=CurrentScanner.asmgetchar;
                    if c in ['0'..'7'] then
                     actasmpattern:=actasmpattern + c
                    else
                     Message(asmr_e_invalid_fpu_register);
                    c:=CurrentScanner.asmgetchar;
                    { allow spaces }
                    while (c in [' ',#9]) do
                      c:=CurrentScanner.asmgetchar;
                    if c <> ')' then
                     Message(asmr_e_invalid_fpu_register)
                    else
                     Begin
                       actasmpattern:=actasmpattern + c;
                       c:=CurrentScanner.asmgetchar;
                     end;
                  end;
                 //if prevasmtoken in [AS_LOPMASK,AS_LOPZEROMASK,AS_LOPBCST,AS_LOPSAE,AS_LOPER] then
                  if prevasmtoken in OPEXT_STARTASMTOKEN then
                  begin
                    if (prevasmtoken = AS_LOPER) and (c = '-') then
                     begin
                       actasmpattern := actasmpattern + c;
                       c:=CurrentScanner.asmgetchar;
                       while c in  ['A'..'Z','a'..'z'] do
                       begin
                         actasmpattern:=actasmpattern + c;
                         c:=CurrentScanner.asmgetchar;
                       end;
                     end;


                    { allow spaces }
                    while (c in [' ',#9]) do
                      c:=CurrentScanner.asmgetchar;

                    if c = '}' then
                     begin
                       CurrentScanner.readchar;
                       case prevasmtoken of
                         AS_LOPMASK: if (length(actasmpattern) = 2) and
                                        (actasmpattern[2] in ['1'..'7']) then
                                      begin
                                        actasmtoken := AS_VOPMASK;
                                      end;
                         AS_LOPZEROMASK:
                                      if (actasmpattern = 'z') or
                                         (actasmpattern = 'Z') then
                                      begin
                                        actasmtoken := AS_VOPZEROMASK;
                                      end;
                             AS_LOPBCST:
                                      begin
                                        actasmpattern_origcase:=actasmpattern;
                                        UpperVar(actasmpattern);

                                        if (actasmpattern = '1TO2') then actasmtoken := AS_OPBCST1TO2
                                         else if (actasmpattern = '1TO4') then actasmtoken := AS_OPBCST1TO4
                                         else if (actasmpattern = '1TO8') then actasmtoken := AS_OPBCST1TO8
                                         else if (actasmpattern = '1TO16') then actasmtoken := AS_OPBCST1TO16
                                         else if (actasmpattern = '1TO32') then actasmtoken := AS_OPBCST1TO32
                                         else actasmpattern := actasmpattern_origcase;
                                      end;
                             AS_LOPSAE:
                                      begin
                                        actasmpattern_origcase:=actasmpattern;
                                        UpperVar(actasmpattern);

                                        if (actasmpattern = 'SAE') then actasmtoken := AS_OPSAE
                                         else actasmpattern := actasmpattern_origcase;
                                      end;
                              AS_LOPER:
                                      begin
                                        actasmpattern_origcase:=actasmpattern;
                                        UpperVar(actasmpattern);

                                        if (actasmpattern = 'RD-SAE') then actasmtoken := AS_OPRDSAE
                                         else if (actasmpattern = 'RN-SAE') then actasmtoken := AS_OPRNSAE
                                         else if (actasmpattern = 'RU-SAE') then actasmtoken := AS_OPRUSAE
                                         else if (actasmpattern = 'RZ-SAE') then actasmtoken := AS_OPRZSAE
                                         else actasmpattern := actasmpattern_origcase;
                                      end

                                 else ; // is completely comment =>> nothing todo

                       end;
                       exit;
                     end
                    else
                     begin
                       if c = '{' then CurrentScanner.inc_comment_level;
                       CurrentScanner.skipcomment(false); // is comment
                       actasmpattern := '';
                       actasmtoken := AS_NONE;
                       exit;
                     end;
                  end;
                 if is_asmdirective(actasmpattern) then
                  exit;
                 if is_asmoperator(actasmpattern) then
                  exit;
                 if is_register(actasmpattern) then
                  exit;
                 { allow spaces }
                 while (c in [' ',#9]) do
                   c:=CurrentScanner.asmgetchar;
                 { if next is a '.' and this is a unitsym then we also need to
                   parse the identifier }
                 if (c='.') then
                  begin
                    asmsearchsym(actasmpattern,srsym,srsymtable);
                    if Assigned(srsym) and
                       (srsym.typ=UnitSym) and
                       (srsym.owner.SymTableType in [staticsymtable,GlobalSymTable]) and
                       srsym.owner.IsCurrentUnit then
                     begin
                       { Add . to create System.Identifier }
                       actasmpattern:=actasmpattern+c;
                       c:=CurrentScanner.asmgetchar;
                       { Delphi allows System.@Halt, just ignore the @ }
                       if c='@' then
                         c:=CurrentScanner.asmgetchar;
                       while c in  ['A'..'Z','a'..'z','0'..'9','_','$'] do
                        begin
                          actasmpattern:=actasmpattern + upcase(c);
                          c:=CurrentScanner.asmgetchar;
                        end;
                     end;
                  end;
                 actasmtoken:=AS_ID;
                 exit;
               end;

             '''' : { string or character }
               begin
                 actasmpattern:='';
                 repeat
                   if c = '''' then
                    begin
                      c:=CurrentScanner.asmgetchar;
                      if c in [#10,#13] then
                       begin
                         Message(scan_f_string_exceeds_line);
                         break;
                       end;
                      repeat
                        if c='''' then
                         begin
                           c:=CurrentScanner.asmgetchar;
                           if c='''' then
                            begin
                              actasmpattern:=actasmpattern+'''';
                              c:=CurrentScanner.asmgetchar;
                              if c in [#10,#13] then
                               begin
                                 Message(scan_f_string_exceeds_line);
                                 break;
                               end;
                            end
                           else
                            break;
                         end
                        else
                         begin
                           actasmpattern:=actasmpattern+c;
                           c:=CurrentScanner.asmgetchar;
                           if c in [#10,#13] then
                            begin
                              Message(scan_f_string_exceeds_line);
                              break
                            end;
                         end;
                      until false; { end repeat }
                    end
                   else
                    break; { end if }
                 until false;
                 actasmtoken:=AS_STRING;
                 exit;
               end;

             '"' : { string or character }
               begin
                 actasmpattern:='';
                 repeat
                   if c = '"' then
                    begin
                      c:=CurrentScanner.asmgetchar;
                      if c in [#10,#13] then
                       begin
                         Message(scan_f_string_exceeds_line);
                         break;
                       end;
                      repeat
                        if c='"' then
                         begin
                           c:=CurrentScanner.asmgetchar;
                           if c='"' then
                            begin
                              actasmpattern:=actasmpattern+'"';
                              c:=CurrentScanner.asmgetchar;
                              if c in [#10,#13] then
                               begin
                                 Message(scan_f_string_exceeds_line);
                                 break;
                               end;
                            end
                           else
                            break;
                         end
                        else
                         begin
                           actasmpattern:=actasmpattern+c;
                           c:=CurrentScanner.asmgetchar;
                           if c in [#10,#13] then
                            begin
                              Message(scan_f_string_exceeds_line);
                              break
                            end;
                         end;
                      until false; { end repeat }
                    end
                   else
                    break; { end if }
                 until false;
                 actasmtoken:=AS_STRING;
                 exit;
               end;

             '$' :
               begin
                 c:=CurrentScanner.asmgetchar;
                 while c in ['0'..'9','A'..'F','a'..'f'] do
                  begin
                    actasmpattern:=actasmpattern + c;
                    c:=CurrentScanner.asmgetchar;
                  end;
                 actasmpattern:=ToStr(ParseVal(actasmpattern,16));
                 actasmtoken:=AS_INTNUM;
                 exit;
               end;

             '&' : { identifier }
               begin
                 actasmpattern:='';
                 c:=CurrentScanner.asmgetchar;
                 while c in  ['A'..'Z','a'..'z','0'..'9','_'] do
                  begin
                    actasmpattern:=actasmpattern + c;
                    c:=CurrentScanner.asmgetchar;
                  end;
                 actasmpattern_origcase:=actasmpattern;
                 UpperVar(actasmpattern);
                 actasmtoken:=AS_ID;
                 exit;
               end;

             ',' :
               begin
                 actasmtoken:=AS_COMMA;
                 c:=CurrentScanner.asmgetchar;
                 exit;
               end;

             '[' :
               begin
                 actasmtoken:=AS_LBRACKET;
                 c:=CurrentScanner.asmgetchar;
                 exit;
               end;

             ']' :
               begin
                 actasmtoken:=AS_RBRACKET;
                 c:=CurrentScanner.asmgetchar;
                 exit;
               end;

             '(' :
               begin
                 c:=CurrentScanner.asmgetchar;
                 if c='*' then
                   begin
                     CurrentScanner.skipoldtpcomment(true);
                     GetToken;
                   end
                 else
                   actasmtoken:=AS_LPAREN;
                 exit;
               end;

             ')' :
               begin
                 actasmtoken:=AS_RPAREN;
                 c:=CurrentScanner.asmgetchar;
                 exit;
               end;

             ':' :
               begin
                 actasmtoken:=AS_COLON;
                 c:=CurrentScanner.asmgetchar;
                 exit;
               end;

             '.' :
               begin
                 c:=CurrentScanner.asmgetchar;
{$ifdef x86_64}
                 if c='.' then
                   begin
                     actasmpattern:='..';
                     c:=CurrentScanner.asmgetchar;
                     repeat
                       actasmpattern:=actasmpattern+c;
                       c:=CurrentScanner.asmgetchar;
                     until not(c in ['A'..'Z','a'..'z','0'..'9','_']);
                     if upper(actasmpattern)<>'..GOTPCREL' then
                       begin
                         actasmtoken:=AS_ID;
                         consume(AS___GOTPCREL);
                       end;
                     actasmtoken:=AS___GOTPCREL
                   end
                 else
{$endif x86_64}
                   actasmtoken:=AS_DOT;
                 exit;
               end;

             '+' :
               begin
                 actasmtoken:=AS_PLUS;
                 c:=CurrentScanner.asmgetchar;
                 exit;
               end;

             '-' :
               begin
                 actasmtoken:=AS_MINUS;
                 c:=CurrentScanner.asmgetchar;
                 exit;
               end;

             '*' :
               begin
                 actasmtoken:=AS_STAR;
                 c:=CurrentScanner.asmgetchar;
                 exit;
               end;

             '/' :
               begin
                 c:=CurrentScanner.asmgetchar;
                 if c='/' then
                   begin
                     CurrentScanner.skipdelphicomment;
                     GetToken;
                   end
                 else
                   actasmtoken:=AS_SLASH;
                 exit;
               end;

             '0'..'9':
               begin
                 if prevasmtoken = AS_LOPBCST then
                 begin
                   actasmpattern:=c;
                   c:=CurrentScanner.asmgetchar;
                   { Get the possible characters }
                   while c in ['1','2','3','4','6','8','t','T','o','O'] do
                    begin
                      actasmpattern:=actasmpattern + c;
                      c:=CurrentScanner.asmgetchar;
                    end;

                   while (c in [' ',#9]) do
                    c:=CurrentScanner.asmgetchar;

                   if c = '}' then
                    begin
                      actasmpattern_origcase:=actasmpattern;
                      UpperVar(actasmpattern);

                      if (actasmpattern = '1TO2') then actasmtoken := AS_OPBCST1TO2
                       else if (actasmpattern = '1TO4') then actasmtoken := AS_OPBCST1TO4
                       else if (actasmpattern = '1TO8') then actasmtoken := AS_OPBCST1TO8
                       else if (actasmpattern = '1TO16') then actasmtoken := AS_OPBCST1TO16
                       else if (actasmpattern = '1TO32') then actasmtoken := AS_OPBCST1TO32
                       else actasmpattern := actasmpattern_origcase;
                       c:=CurrentScanner.asmgetchar;
                    end
                    else
                    begin
                      if c = '{' then CurrentScanner.inc_comment_level;
                      CurrentScanner.skipcomment(false); // is comment
                    end;

                    actasmpattern := '';
                    exit;
                 end
                 else
                 begin

                   actasmpattern:=c;
                   c:=CurrentScanner.asmgetchar;
                   { Get the possible characters }
                   while c in ['0'..'9','A'..'F','a'..'f'] do
                    begin
                      actasmpattern:=actasmpattern + c;
                      c:=CurrentScanner.asmgetchar;
                    end;
                   { Get ending character }
                   actasmpattern_origcase:=actasmpattern;
                   UpperVar(actasmpattern);
                   c:=upcase(c);
                   { possibly a binary number. }
                   if (actasmpattern[length(actasmpattern)] = 'B') and (c <> 'H') then
                    Begin
                      { Delete the last binary specifier }
                      delete(actasmpattern,length(actasmpattern),1);
                      actasmpattern:=ToStr(ParseVal(actasmpattern,2));
                      actasmtoken:=AS_INTNUM;
                      exit;
                    end
                   else
                    Begin
                      case c of
                        'O' :
                          Begin
                            actasmpattern:=ToStr(ParseVal(actasmpattern,8));
                            actasmtoken:=AS_INTNUM;
                            c:=CurrentScanner.asmgetchar;
                            exit;
                          end;
                        'H' :
                          Begin
                            actasmpattern:=ToStr(ParseVal(actasmpattern,16));
                            actasmtoken:=AS_INTNUM;
                            c:=CurrentScanner.asmgetchar;
                            exit;
                          end;
                        else { must be an integer number }
                          begin
                            actasmpattern:=ToStr(ParseVal(actasmpattern,10));
                            actasmtoken:=AS_INTNUM;
                            exit;
                          end;
                      end;
                   end;
                 end;
               end;

             #13,#10:
               begin
                 CurrentScanner.linebreak;
                 c:=CurrentScanner.asmgetchar;
                 firsttoken:=TRUE;
                 actasmtoken:=AS_SEPARATOR;
                 exit;
               end;

             ';':
               begin
                 c:=CurrentScanner.asmgetchar;
                 firsttoken:=TRUE;
                 actasmtoken:=AS_SEPARATOR;
                 exit;
               end;

             '{':
               begin
                 if not(check_operand_extention) then CurrentScanner.skipcomment(true)
                  else  // exists operand extention e.g. AVX512 {k1..k7} or {z} or {1to8}
                  begin
                    case CurrentScanner.asmgetchar of
                      '{': begin
                             CurrentScanner.inc_comment_level;
                             CurrentScanner.skipcomment(true);
                           end;
                      '}': ; // local comment closed
                      'k',
                      'K': begin
                             actasmtoken := AS_LOPMASK;
                             exit;
                           end;
                      'z',
                      'Z': begin
                             actasmtoken := AS_LOPZEROMASK;
                             exit;
                           end;

                      '1': begin
                             actasmtoken := AS_LOPBCST;
                             exit;
                           end;
                      's',
                      'S': begin
                             actasmtoken := AS_LOPSAE;
                             exit;
                           end;
                      'r',
                      'R': begin
                             actasmtoken := AS_LOPER;
                             exit;
                           end;
                      else begin
                             CurrentScanner.skipcomment(false);
                           end;
                    end;
                  end;

                 GetToken(check_operand_extention);
               end;

              else
                 CurrentScanner.illegal_char(c);
           end;
         end;
      end;


  function TX86IntReader.consume(t : TAsmToken; check_operand_extention: boolean):boolean;
    begin
      Consume:=true;
      if t<>actasmtoken then
       begin
         Message2(scan_f_syn_expected,token2str[t],token2str[actasmtoken]);
         Consume:=false;
       end;
      repeat
        gettoken(check_operand_extention);
      until actasmtoken<>AS_NONE;
    end;

  //procedure tx86intreader.ConsumeOperExtention(oper: tx86operand; const aOperExtention: string);
  //begin
  //  //if oper.reg
  //end;

  procedure TX86IntReader.consume_voperand_ext(aop: tx86operand; aConsumeVOpExt: boolean);
  var
    kreg: TRegister;
  begin
    Consume(actasmtoken, true);
    if actasmtoken in [AS_VOPMASK, AS_VOPZEROMASK, AS_OPBCST1TO2, AS_OPBCST1TO4, AS_OPBCST1TO8, AS_OPBCST1TO16, AS_OPBCST1TO32,
                       AS_OPSAE,AS_OPRNSAE,AS_OPRDSAE,AS_OPRUSAE,AS_OPRZSAE] then
    begin
      case actasmtoken of
            AS_VOPMASK: begin
                          kreg := masm_regnum_search(lower(actasmpattern));
                          if (kreg >= NR_K1) and
                             (kreg <= NR_K7) then
                          begin
                            aop.vopext := aop.vopext or (TRegisterRec(kreg).SupReg  and $07);
                            aop.vopext := aop.vopext or OTVE_VECTOR_WRITEMASK;
                          end;
                        end;
        AS_VOPZEROMASK: aop.vopext := aop.vopext or OTVE_VECTOR_ZERO;
         AS_OPBCST1TO2: begin
                          aop.vopext := aop.vopext or OTVE_VECTOR_BCST or OTVE_VECTOR_BCST2;
                          aop.vbcst  := 2;
                        end;
         AS_OPBCST1TO4: begin
                          aop.vopext := aop.vopext or OTVE_VECTOR_BCST or OTVE_VECTOR_BCST4;
                          aop.vbcst  := 4;
                        end;
         AS_OPBCST1TO8: begin
                          aop.vopext := aop.vopext or OTVE_VECTOR_BCST or OTVE_VECTOR_BCST8;
                          aop.vbcst  := 8;
                        end;
        AS_OPBCST1TO16: begin
                          aop.vopext := aop.vopext or OTVE_VECTOR_BCST or OTVE_VECTOR_BCST16;
                          aop.vbcst  := 16;
                        end;
        AS_OPBCST1TO32: begin
                          aop.vopext := aop.vopext or OTVE_VECTOR_BCST or OTVE_VECTOR_BCST32;
                          aop.vbcst  := 32;
                        end;
              AS_OPSAE: aop.vopext := aop.vopext or OTVE_VECTOR_SAE;
            AS_OPRNSAE: aop.vopext := aop.vopext or OTVE_VECTOR_RNSAE;
            AS_OPRDSAE: aop.vopext := aop.vopext or OTVE_VECTOR_RDSAE;
            AS_OPRUSAE: aop.vopext := aop.vopext or OTVE_VECTOR_RUSAE;
            AS_OPRZSAE: aop.vopext := aop.vopext or OTVE_VECTOR_RZSAE;
        else
          InternalError(2019081009);
      end;

      if aConsumeVOpExt then
       Consume(actasmtoken, true);
    end;
  end;

  procedure TX86IntReader.RecoverConsume(allowcomma:boolean);
    begin
      While not (actasmtoken in [AS_SEPARATOR,AS_END]) do
       begin
         if allowcomma and (actasmtoken=AS_COMMA) then
          break;
         Consume(actasmtoken);
       end;
    end;


{*****************************************************************************
                                 Parsing Helpers
*****************************************************************************}

    { Adds two references (dest:=dest+src) }
    procedure TX86IntReader.AddReferences(dest,src : tx86operand);

      procedure AddRegister(reg:TRegister;ScaleFactor:byte);
        begin
          if reg=NR_NO then
            exit;
          if (dest.opr.Ref.Base=NR_NO) and (ScaleFactor=1) then
            begin
              dest.opr.Ref.Base:=reg;
              exit;
            end;
          if dest.opr.Ref.Index=NR_NO then
            begin
              dest.opr.Ref.Index:=reg;
              dest.opr.Ref.ScaleFactor:=ScaleFactor;
              exit;
            end;
          if dest.opr.Ref.Index=reg then
            begin
              Inc(dest.opr.Ref.ScaleFactor,ScaleFactor);
              exit;
            end;
          Message(asmr_e_multiple_index);
        end;

      var
        tmplocal: TOprRec;
        segreg: TRegister;
      begin
        case dest.opr.typ of
          OPR_REFERENCE:
            begin
              case src.opr.typ of
                OPR_REFERENCE:
                  begin
                    AddRegister(src.opr.Ref.Base,1);
                    AddRegister(src.opr.Ref.Index,src.opr.Ref.ScaleFactor);
                    if src.opr.Ref.Segment<>NR_NO then
                      SetSegmentOverride(dest,src.opr.Ref.Segment);
                    Inc(dest.opr.Ref.Offset,src.opr.Ref.Offset);
                    Inc(dest.opr.constoffset,src.opr.constoffset);
                    dest.haslabelref:=dest.haslabelref or src.haslabelref;
                    dest.hasproc:=dest.hasproc or src.hasproc;
                    dest.hasvar:=dest.hasvar or src.hasvar;
                    if Assigned(src.opr.Ref.Symbol) then
                      begin
                        if Assigned(dest.opr.Ref.Symbol) then
                          Message(asmr_e_cant_have_multiple_relocatable_symbols);
                        dest.opr.Ref.Symbol:=src.opr.Ref.Symbol;
                      end;
                    if Assigned(src.opr.Ref.RelSymbol) then
                      begin
                        if Assigned(dest.opr.Ref.RelSymbol) then
                          Message(asmr_e_cant_have_multiple_relocatable_symbols);
                        dest.opr.Ref.RelSymbol:=src.opr.Ref.RelSymbol;
                      end;
                    if dest.opr.Ref.RefAddr=addr_no then
                      dest.opr.Ref.RefAddr:=src.opr.Ref.RefAddr;
                  end;
                OPR_LOCAL:
                  begin
                    tmplocal:=src.opr;
                    if dest.opr.Ref.Base<>NR_NO then
                      begin
                        if tmplocal.localindexreg=NR_NO then
                          begin
                            tmplocal.localindexreg:=dest.opr.Ref.Base;
                            tmplocal.localscale:=0;
                          end
                        else if tmplocal.localindexreg=dest.opr.Ref.Base then
                          tmplocal.localscale:=Min(tmplocal.localscale,1)+1
                        else
                          Message(asmr_e_multiple_index);
                      end;
                    if dest.opr.Ref.Index<>NR_NO then
                      begin
                        if tmplocal.localindexreg=NR_NO then
                          begin
                            tmplocal.localindexreg:=dest.opr.Ref.Index;
                            tmplocal.localscale:=dest.opr.Ref.ScaleFactor;
                          end
                        else if tmplocal.localindexreg=dest.opr.Ref.Index then
                          tmplocal.localscale:=Min(tmplocal.localscale,1)+Min(dest.opr.Ref.ScaleFactor,1)
                        else
                          Message(asmr_e_multiple_index);
                      end;
                    Inc(tmplocal.localconstoffset,dest.opr.constoffset);
                    Inc(tmplocal.localsymofs,dest.opr.Ref.Offset);
                    segreg:=dest.opr.Ref.Segment;
                    dest.opr:=tmplocal;
                    if segreg<>NR_NO then
                      SetSegmentOverride(dest,segreg);
                  end;
                else
                  InternalError(2018030704);
              end;
            end;
          OPR_LOCAL:
            begin
              case src.opr.typ of
                OPR_REFERENCE:
                  begin
                    if src.opr.Ref.Base<>NR_NO then
                      begin
                        if dest.opr.localindexreg=NR_NO then
                          begin
                            dest.opr.localindexreg:=src.opr.Ref.Base;
                            dest.opr.localscale:=0;
                          end
                        else if dest.opr.localindexreg=src.opr.Ref.Base then
                          dest.opr.localscale:=Min(dest.opr.localscale,1)+1
                        else
                          Message(asmr_e_multiple_index);
                      end;
                    if src.opr.Ref.Index<>NR_NO then
                      begin
                        if dest.opr.localindexreg=NR_NO then
                          begin
                            dest.opr.localindexreg:=src.opr.Ref.Index;
                            dest.opr.localscale:=src.opr.Ref.ScaleFactor;
                          end
                        else if dest.opr.localindexreg=src.opr.Ref.Index then
                          dest.opr.localscale:=Min(dest.opr.localscale,1)+Min(src.opr.Ref.ScaleFactor,1)
                        else
                          Message(asmr_e_multiple_index);
                      end;
                    Inc(dest.opr.localconstoffset,src.opr.constoffset);
                    Inc(dest.opr.localsymofs,src.opr.Ref.Offset);
                    if src.opr.Ref.Segment<>NR_NO then
                      SetSegmentOverride(dest,src.opr.Ref.Segment);
                  end;
                OPR_LOCAL:
                  Message(asmr_e_no_local_or_para_allowed);
                else
                  InternalError(2018030703);
              end;
            end;
          else
            InternalError(2018030702);
        end;
      end;


    procedure TX86IntReader.SetSegmentOverride(oper:tx86operand;seg:TRegister);
      begin
        if not is_segment_reg(seg) then
          Message(asmr_e_invalid_seg_override);
{$ifdef x86_64}
        if (seg=NR_CS) or (seg=NR_DS) or (seg=NR_SS) or (seg=NR_ES) then
          Message1(asmr_w_segment_override_ignored_in_64bit_mode,masm_regname(seg));
{$endif x86_64}
        case oper.opr.typ of
          OPR_REFERENCE:
            begin
              if oper.opr.Ref.Segment<>NR_NO then
                begin
                  Message(asmr_e_multiple_segment_overrides);
                end;
              oper.opr.Ref.Segment:=seg;
            end;
          OPR_LOCAL:
            begin
              if oper.opr.localsegment<>NR_NO then
                begin
                  Message(asmr_e_multiple_segment_overrides);
                end;
              oper.opr.localsegment:=seg;
            end;
          else
            InternalError(2018030705);
        end;
      end;


    { This routine builds up a record offset after a AS_DOT
      token is encountered.
      On entry actasmtoken should be equal to AS_DOT                     }
    Procedure TX86IntReader.BuildRecordOffsetSize(const expr: string;out offset:TCGInt;out size:TCGInt; out MangledName: string; needvmtofs: boolean; out hastypecast: boolean);
      var
        s: string;
      Begin
        offset:=0;
        size:=0;
        MangledName:='';
        hastypecast:=false;
        s:=expr;
        while (actasmtoken=AS_DOT) do
         begin
           Consume(AS_DOT);
           if actasmtoken in [AS_BYTE,AS_ID,AS_WORD,AS_DWORD,AS_QWORD,AS_OWORD,AS_XMMWORD,AS_YWORD,AS_YMMWORD,AS_ZWORD,AS_ZMMWORD,AS_REGISTER] then
             begin
               s:=s+'.'+actasmpattern;
               consume(actasmtoken);
             end
           else
            begin
              Consume(AS_ID);
              RecoverConsume(true);
              break;
            end;
         end;
        if not GetRecordOffsetSize(s,offset,size,MangledName,needvmtofs,hastypecast) then
          Message(asmr_e_building_record_offset);
      end;


    Procedure TX86IntReader.BuildConstSymbolExpression(in_flags: TConstSymbolExpressionInputFlags;out value:TCGInt;out asmsym:string;out asmsymtyp:TAsmsymtype;out size:TCGInt;out out_flags:TConstSymbolExpressionOutputFlags);
      var
        tempstr,expr,hs,MangledName : string;
        parenlevel : LongInt;
        l,k : TCGInt;
        hasparen,
        errorflag,
        needvmtofs : boolean;
        prevtok : TAsmToken;
        hl : TAsmLabel;
        hssymtyp : TAsmsymtype;
        def : TDef;
        sym : TSym;
        srsymtable : TSymTable;
        hastypecast : boolean;
	stop_at_plus_minus: boolean;
      Begin
        { reset }
        value:=0;
        asmsym:='';
        asmsymtyp:=AT_DATA;
        size:=0;
        out_flags:=[];
        errorflag:=FALSE;
        tempstr:='';
        expr:='';
        if cseif_startingminus in in_flags then
          expr:='-';
        inexpression:=TRUE;
        parenlevel:=0;
        sym:=nil;
        needvmtofs:=FALSE;
	stop_at_plus_minus:=(prevasmtoken in high_priority_tokens);
        Repeat
          { Support ugly delphi constructs like: [ECX].1+2[EDX] }
          if (cseif_isref in in_flags) and (actasmtoken=AS_LBRACKET) then
            break;
          if (cseif_referencelike in in_flags) and
             (actasmtoken in [AS_BYTE,AS_WORD,AS_DWORD,AS_QWORD,AS_TBYTE,AS_DQWORD,AS_OWORD,AS_XMMWORD,AS_YWORD,AS_YMMWORD]) then
            begin
              { Support ugly tp7 and delphi constructs like 'DD DWORD PTR 5' }
              Consume(actasmtoken);
              Consume(AS_PTR);
            end;
          if (cseif_referencelike in in_flags) and
             (actasmtoken in [AS_LBRACKET,AS_RBRACKET]) then
            case actasmtoken of
              AS_LBRACKET:
                begin
                  Consume(AS_LBRACKET);
                  if (length(expr)>0) and
                     not (expr[length(expr)] in ['+','-']) then
                    expr:=expr+'+';
                  expr:=expr+'[';
                end;
              AS_RBRACKET:
                begin
                  Consume(AS_RBRACKET);
                  expr:=expr+']';
                end;
              else
                ;
            end;
          Case actasmtoken of
            AS_LPAREN:
              Begin
                Consume(AS_LPAREN);
                expr:=expr + '(';
                inc(parenlevel);
              end;
            AS_RPAREN:
              Begin
                { Keep the AS_PAREN in actasmtoken, it is maybe a typecast }
                if parenlevel=0 then
                  break;
                Consume(AS_RPAREN);
                expr:=expr + ')';
                dec(parenlevel);
              end;
            AS_SHL:
              Begin
                Consume(AS_SHL);
                expr:=expr + '<';
              end;
            AS_SHR:
              Begin
                Consume(AS_SHR);
                expr:=expr + '>';
              end;
            AS_SLASH:
              Begin
                Consume(AS_SLASH);
                expr:=expr + '/';
              end;
            AS_MOD:
              Begin
                Consume(AS_MOD);
                expr:=expr + '%';
              end;
            AS_STAR:
              Begin
                Consume(AS_STAR);
                if (cseif_isref in in_flags) and (actasmtoken=AS_REGISTER) then
                 break;
                expr:=expr + '*';
              end;
            AS_PLUS:
              Begin
                if (parenlevel=0) and stop_at_plus_minus then
                 break;
                Consume(AS_PLUS);
                if (cseif_isref in in_flags) and ((actasmtoken=AS_REGISTER) or (actasmtoken=AS_LBRACKET)) then
                 break;
                expr:=expr + '+';
              end;
            AS_MINUS:
              Begin
                if (parenlevel=0) and stop_at_plus_minus then
                 break;
                Consume(AS_MINUS);
                expr:=expr + '-';
              end;
            AS_AND:
              Begin
                Consume(AS_AND);
                expr:=expr + '&';
              end;
            AS_NOT:
              Begin
                Consume(AS_NOT);
                expr:=expr + '~';
              end;
            AS_XOR:
              Begin
                Consume(AS_XOR);
                expr:=expr + '^';
              end;
            AS_OR:
              Begin
                Consume(AS_OR);
                expr:=expr + '|';
              end;
            AS_INTNUM:
              Begin
                expr:=expr + actasmpattern;
                Consume(AS_INTNUM);
              end;

            AS_VMTOFFSET,
            AS_OFFSET:
              begin
                if (actasmtoken = AS_OFFSET) then
                  begin
                    include(in_flags,cseif_needofs);
                    include(out_flags,cseof_hasofs);
                  end
                else
                  needvmtofs:=true;
                Consume(actasmtoken);
                if actasmtoken<>AS_ID then
                 Message(asmr_e_offset_without_identifier);
              end;
            AS_SIZEOF,
            AS_TYPE:
              begin
                l:=0;
                hasparen:=false;
                Consume(actasmtoken);
                if actasmtoken=AS_LPAREN then
                  begin
                    hasparen:=true;
                    Consume(AS_LPAREN);
                  end;
                if actasmtoken<>AS_ID then
                 Message(asmr_e_type_without_identifier)
                else
                 begin
                   tempstr:=actasmpattern;
                   Consume(AS_ID);
                   if actasmtoken=AS_DOT then
                     begin
                       BuildRecordOffsetSize(tempstr,k,l,MangledName,false,hastypecast);
                       if MangledName<>'' then
                         { procsym }
                         Message(asmr_e_wrong_sym_type);
                       if hastypecast then

                     end
                   else
                    begin
                      asmsearchsym(tempstr,sym,srsymtable);
                      if Assigned(sym) then
                       begin
                         case sym.typ of
                           staticvarsym,
                           localvarsym,
                           paravarsym :
                             l:=TAbstractVarSym(sym).GetSize;
                           TypeSym :
                             l:=TTypeSym(sym).typedef.Size;
                           else
                             Message(asmr_e_wrong_sym_type);
                         end;
                       end
                      else
                       Message1(sym_e_unknown_id,tempstr);
                    end;
                 end;
                str(l, tempstr);
                expr:=expr + tempstr;
                if hasparen then
                  Consume(AS_RPAREN);
              end;
            AS_PTR :
              begin
                { Support ugly delphi constructs like <constant> PTR [ref] }
                break;
              end;
            AS_STRING:
              begin
                l:=0;
                case Length(actasmpattern) of
                 1 :
                  l:=ord(actasmpattern[1]);
                 2 :
                  l:=ord(actasmpattern[2]) + ord(actasmpattern[1]) shl 8;
                 3 :
                  l:=ord(actasmpattern[3]) +
                     Ord(actasmpattern[2]) shl 8 + ord(actasmpattern[1]) shl 16;
                 4 :
                  l:=ord(actasmpattern[4]) + ord(actasmpattern[3]) shl 8 +
                     Ord(actasmpattern[2]) shl 16 + ord(actasmpattern[1]) shl 24;
                 8 :
                  begin
                    move(actasmpattern[1],l,8);
                    l:=SwapEndian(l);
                  end;
                else
                  Message1(asmr_e_invalid_string_as_opcode_operand,actasmpattern);
                end;
                str(l, tempstr);
                expr:=expr + tempstr;
                Consume(AS_STRING);
              end;
            AS_ID:
              begin
                hs:='';
                hssymtyp:=AT_DATA;
                def:=nil;
                tempstr:=actasmpattern;
                prevtok:=prevasmtoken;
                { stop parsing a constant expression if we find an opcode after a
                  non-operator like "db $66 mov eax,ebx" }
                if (prevtok in [AS_ID,AS_INTNUM,AS_RPAREN]) and
                   is_asmopcode(actasmpattern) then
                  break;
                consume(AS_ID);
                if (tempstr='@CODE') or (tempstr='@DATA') then
                 begin
                   if asmsym='' then
                     begin
                       asmsym:=tempstr;
                       asmsymtyp:=AT_SECTION;
                     end
                   else
                    Message(asmr_e_cant_have_multiple_relocatable_symbols);
                 end
                else if SearchIConstant(tempstr,l) then
                 begin
                   str(l, tempstr);
                   expr:=expr + tempstr;
                 end
                else
                 begin
                   if is_locallabel(tempstr) then
                    begin
                      CreateLocalLabel(tempstr,hl,false);
                      hs:=hl.name;
                      hssymtyp:=AT_FUNCTION;
                    end
                   else
                    if SearchLabel(tempstr,hl,false) then
                      begin
                        hs:=hl.name;
                        hssymtyp:=AT_FUNCTION;
                      end
                   else
                    begin
                      asmsearchsym(tempstr,sym,srsymtable);
                      if Assigned(sym) then
                       begin
                         case sym.typ of
                           staticvarsym :
                             begin
                               hs:=TStaticVarSym(sym).MangledName;
                               def:=TStaticVarSym(sym).vardef;
                             end;
                           localvarsym,
                           paravarsym :
                             begin
                               Message(asmr_e_no_local_or_para_allowed);
                             end;
                           ProcSym :
                             begin
                               if TProcSym(sym).ProcdefList.Count>1 then
                                Message(asmr_w_calling_overload_func);
                               hs:=TProcDef(TProcSym(sym).ProcdefList[0]).MangledName;

                               hssymtyp:=AT_FUNCTION;
                             end;
                           TypeSym :
                             begin
                               if not(TTypeSym(sym).typedef.typ in [recorddef,objectdef]) then
                                Message(asmr_e_wrong_sym_type);
                               size:=TTypeSym(sym).typedef.Size;
                             end;
                           FieldVarSym :
                             begin
                               tempstr:=upper(TDef(sym.owner.DefOwner).GetTypeName)+'.'+tempstr;
                             end;
                           else
                             Message(asmr_e_wrong_sym_type);
                         end;
                       end
                      else
                       Message1(sym_e_unknown_id,tempstr);
                    end;
                   { symbol found? }
                   if hs<>'' then
                    begin
                      if asmsym='' then
                        begin
                          asmsym:=hs;
                          asmsymtyp:=hssymtyp;
                        end
                      else
                       Message(asmr_e_cant_have_multiple_relocatable_symbols);
                      if (expr='') or (expr[length(expr)]='+') then
                       begin
                         { don't remove the + if there could be a record field }
                         if actasmtoken<>AS_DOT then
                          delete(expr,length(expr),1);
                       end
                      else
                       if (cseif_needofs in in_flags) then
                         begin
                           if (prevtok<>AS_OFFSET) then
                             Message(asmr_e_need_offset);
                         end
                       else
                         Message(asmr_e_only_add_relocatable_symbol);
                    end;
                   if (actasmtoken=AS_DOT) or
                      (Assigned(sym) and
                       Is_Normal_FieldVarSym(sym)) then
                     begin
                      BuildRecordOffsetSize(tempstr,l,size,hs,needvmtofs,hastypecast);
                      if hs <> '' then
                        hssymtyp:=AT_FUNCTION
                      else
                        begin
                          str(l, tempstr);
                          expr:=expr + tempstr;
                        end
                    end
                   else if (actasmtoken<>AS_DOT) and
                           Assigned(sym) and
                           (sym.typ=TypeSym) and
                           (TTypeSym(sym).typedef.typ in [recorddef,objectdef]) then
                     begin
                       { just a record type (without being followed by dot)
                         evaluates to 0. Ugly, but TP7 compatible. }
                       expr:=expr+'0';
                     end
                   else
                    begin
                      if (expr='') or (expr[length(expr)] in ['+','-','/','*']) then
                       delete(expr,length(expr),1);
                    end;
                   if (actasmtoken=AS_LBRACKET) and
                      Assigned(def) and
                      (def.typ=arraydef) then
                     begin
                       consume(AS_LBRACKET);
                       l:=BuildConstExpression;
                       if l<TArrayDef(def).LowRange then
                         begin
                           Message(asmr_e_constant_out_of_bounds);
                           l:=0;
                         end
                       else
                         l:=(l-TArrayDef(def).LowRange)*TArrayDef(def).EleSize;
                       str(l, tempstr);
                       expr:=expr + '+' + tempstr;
                       consume(AS_RBRACKET);
                     end;
                 end;
                { check if there are wrong operator used like / or mod etc. }
                if (hs<>'') and not(actasmtoken in [AS_MINUS,AS_PLUS,AS_COMMA,AS_SEPARATOR,AS_END,AS_RBRACKET]) then
                 Message(asmr_e_only_add_relocatable_symbol);
              end;
            AS_ALIGN,
            AS_DB,
            AS_DW,
            AS_DD,
            AS_DQ,
            AS_END,
            AS_RBRACKET,
            AS_SEPARATOR,
            AS_COMMA,
            AS_COLON:
              break;
          else
            begin
              { write error only once. }
              if not errorflag then
                Message(asmr_e_invalid_constant_expression);
              { consume tokens until we find COMMA or SEPARATOR }
              Consume(actasmtoken);
              errorflag:=TRUE;
            end;
          end;
        Until false;
        { calculate expression }
        if not ErrorFlag then
          value:=CalculateExpression(expr)
        else
          value:=0;
        { no longer in an expression }
        inexpression:=FALSE;
      end;


    Function TX86IntReader.BuildConstExpression:aint;
      var
        l,size : TCGInt;
        hs : string;
        hssymtyp : TAsmsymtype;
        out_flags : TConstSymbolExpressionOutputFlags;
      begin
        BuildConstSymbolExpression([],l,hs,hssymtyp,size,out_flags);
        if hs<>'' then
         Message(asmr_e_relocatable_symbol_not_allowed);
        BuildConstExpression:=aint(l);
      end;


    Function TX86IntReader.BuildRefConstExpression(out size:TCGInt;startingminus:boolean):aint;
      var
        l : TCGInt;
        hs : string;
        hssymtyp : TAsmsymtype;
        in_flags : TConstSymbolExpressionInputFlags;
        out_flags : TConstSymbolExpressionOutputFlags;
      begin
        in_flags:=[cseif_isref];
        if startingminus then
          include(in_flags,cseif_startingminus);
        BuildConstSymbolExpression(in_flags,l,hs,hssymtyp,size,out_flags);
        if hs<>'' then
         Message(asmr_e_relocatable_symbol_not_allowed);
        BuildRefConstExpression:=aint(l);
      end;


    procedure TX86IntReader.BuildReference(oper : tx86operand);
      var
        scale : byte;
        k,l,size : TCGInt;
        tempstr,hs : string;
        tempsymtyp : TAsmsymtype;
        code : integer;
        hreg : TRegister;
        GotStar,GotOffset,HadVar,
        GotPlus,Negative,BracketlessReference : boolean;
        hl : TAsmLabel;
        hastypecast: boolean;
        tmpoper: tx86operand;
        refparasym: TAbstractNormalVarSym;
        cse_in_flags: TConstSymbolExpressionInputFlags;
        cse_out_flags: TConstSymbolExpressionOutputFlags;
      Begin
        if actasmtoken=AS_LBRACKET then
          begin
            Consume(AS_LBRACKET);
            BracketlessReference:=false;
          end
        else
          BracketlessReference:=true;
        if not(oper.opr.typ in [OPR_LOCAL,OPR_REFERENCE]) then
          oper.InitRef;
        GotStar:=false;
        GotPlus:=true;
        GotOffset:=false;
        Negative:=false;
        Scale:=0;
        repeat
          if GotOffset and (actasmtoken<>AS_ID) then
            Message(asmr_e_invalid_reference_syntax);

          Case actasmtoken of
            AS_ID, { Constant reference expression OR variable reference expression }
            AS_VMTOFFSET:
              Begin
                if not GotPlus then
                  Message(asmr_e_invalid_reference_syntax);
                GotStar:=false;
                GotPlus:=false;
                if (actasmtoken = AS_VMTOFFSET) or
                   (SearchIConstant(actasmpattern,l) or
                    SearchRecordType(actasmpattern)) then
                 begin
                   l:=BuildRefConstExpression(size,negative);
                   if size<>0 then
                     oper.SetSize(size,false);
                   negative:=false;   { "l" was negated if necessary }
                   GotPlus:=(prevasmtoken=AS_PLUS);
                   GotStar:=(prevasmtoken=AS_STAR);
                   case oper.opr.typ of
                     OPR_LOCAL :
                       begin
                         if GotStar then
                           Message(asmr_e_invalid_reference_syntax);
                         Inc(oper.opr.localsymofs,l);
                       end;
                     OPR_REFERENCE :
                       begin
                         if GotStar then
                          oper.opr.Ref.ScaleFactor:=l
                         else
                           Inc(oper.opr.Ref.Offset,l);
                       end;
                     else
                       InternalError(2019050715);
                   end;
                 end
                else
                 Begin
                   if negative and not oper.hasvar then
                     Message(asmr_e_only_add_relocatable_symbol)
                   else if oper.hasvar and not GotOffset and
                           (not negative or Assigned(oper.opr.Ref.RelSymbol)) then
                     Message(asmr_e_cant_have_multiple_relocatable_symbols);
                   HadVar:=oper.hasvar and GotOffset;
                   tempstr:=actasmpattern;
                   Consume(AS_ID);
                   { typecasting? }
                   if (actasmtoken=AS_LPAREN) and
                      SearchType(tempstr,l) then
                    begin
                      oper.hastype:=true;
                      oper.typesize:=l;
                      Consume(AS_LPAREN);
                      BuildOperand(oper,true);
                      Consume(AS_RPAREN);
                    end
                   else
                    if is_locallabel(tempstr) then
                      begin
                        CreateLocalLabel(tempstr,hl,false);
                        oper.InitRef;
                        oper.haslabelref:=true;
                        if not negative then
                          begin
                            oper.opr.Ref.Symbol:=hl;
                            oper.hasvar:=true;
                          end
                        else
                          oper.opr.Ref.RelSymbol:=hl;

                      end
                   else
                    if oper.SetupVar(tempstr,GotOffset) then
                     begin
                       { convert OPR_LOCAL register para into a reference base }
                       if (oper.opr.typ=OPR_LOCAL) and
                          AsmRegisterPara(oper.opr.localsym) then
                         begin
                           refparasym:=oper.opr.localsym;
                           oper.InitRefConvertLocal;
                           if not oper.hastype then
                             begin
                               { The register contains the address, so the
                                 parameter size is not the referenced data size. }
                               oper.Size:=OS_NO;
                               oper.opsize:=S_NO;
                               { A by-reference formal is different: the register
                                 holds the address of the parameter's own type,
                                 so a scalar vardef states the dereferenced width
                                 exactly - "mov [Value],0" on a var UInt64 is a
                                 qword store.  A value Pointer or an ABI-indirect
                                 aggregate keeps the width unknown, and an
                                 explicit "ptr" above stays authoritative. }
                               if (refparasym.VarSpez in [vs_var,vs_out,vs_constref]) and
                                  (refparasym.vardef.typ in [orddef,enumdef,floatdef,pointerdef,classrefdef]) then
                                 oper.SetSize(refparasym.vardef.Size,false);
                             end;
                         end
                       else
                         begin
{$ifdef x86_64}
                           if actasmtoken=AS_WRT then
                             begin
                               if (oper.opr.typ=OPR_REFERENCE) then
                                 begin
                                   Consume(AS_WRT);
                                   Consume(AS___GOTPCREL);
                                   if (oper.opr.Ref.Base<>NR_NO) or
                                      (oper.opr.Ref.Index<>NR_NO) or
                                      (oper.opr.Ref.Offset<>0) then
                                     Message(asmr_e_wrong_gotpcrel_intel_syntax);
                                   if tf_no_pic_supported in TargetInfo.flags then
                                     Message(asmr_e_no_gotpcrel_support);
                                   oper.opr.Ref.RefAddr:=addr_pic;
                                   oper.opr.Ref.Base:=NR_RIP;
                                 end
                               else
                                 message(asmr_e_invalid_reference_syntax);
                             end;
{$endif x86_64}
                         end;
                     end
                   else
                     Message1(sym_e_unknown_id,tempstr);
                   { record.field ? }
                   if actasmtoken=AS_DOT then
                    begin
                      BuildRecordOffsetSize(tempstr,l,k,hs,false,hastypecast);
                      if (hs<>'') then
                        Message(asmr_e_invalid_symbol_ref);
                      case oper.opr.typ of
                        OPR_LOCAL :
                          inc(oper.opr.localsymofs,l);
                        OPR_REFERENCE :
                          inc(oper.opr.Ref.Offset,l);
                        else
                          InternalError(2019050716);
                      end;
                      if hastypecast then
                       oper.hastype:=true;
                      oper.SetSize(k,false);
                    end;
                   if GotOffset then
                    begin
                      if oper.hasvar and (oper.opr.Ref.Base=CurrentProcInfo.framepointer) then
                       begin
                         if (oper.opr.typ=OPR_REFERENCE) then
                           oper.opr.Ref.Base:=NR_NO;
                         oper.hasvar:=hadvar;
                       end
                      else
                       begin
                         if oper.hasvar and hadvar then
                          Message(asmr_e_cant_have_multiple_relocatable_symbols);
                         { should we allow ?? }
                       end;
                    end;
                 end;
                GotOffset:=false;
              end;

            AS_PLUS :
              Begin
                Consume(AS_PLUS);
                Negative:=false;
                GotPlus:=true;
                GotStar:=false;
                Scale:=0;
              end;

            AS_DOT :
              Begin
                { Handle like a + }
                Consume(AS_DOT);
                Negative:=false;
                GotPlus:=true;
                GotStar:=false;
                Scale:=0;
              end;

            AS_MINUS :
              begin
                Consume(AS_MINUS);
                Negative:=true;
                GotPlus:=true;
                GotStar:=false;
                Scale:=0;
              end;

            AS_STAR : { Scaling, with eax*4 order }
              begin
                Consume(AS_STAR);
                hs:='';
                l:=0;
                case actasmtoken of
                  AS_ID,
                  AS_LPAREN :
                    l:=BuildConstExpression;
                  AS_INTNUM:
                    Begin
                      hs:=actasmpattern;
                      Consume(AS_INTNUM);
                    end;
                  AS_REGISTER :
                    begin
                      case oper.opr.typ of
                        OPR_REFERENCE :
                          begin
                            if oper.opr.Ref.ScaleFactor=0 then
                              begin
                                if scale<>0 then
                                  begin
                                    oper.opr.Ref.ScaleFactor:=scale;
                                    scale:=0;
                                  end
                                else
                                 Message(asmr_e_wrong_scale_factor);
                              end
                            else
                              Message(asmr_e_invalid_reference_syntax);
                          end;
                        OPR_LOCAL :
                          begin
                            if oper.opr.localscale=0 then
                              begin
                                if scale<>0 then
                                  begin
                                    oper.opr.localscale:=scale;
                                    scale:=0;
                                  end
                                else
                                 Message(asmr_e_wrong_scale_factor);
                              end
                            else
                              Message(asmr_e_invalid_reference_syntax);
                          end;
                        else
                          InternalError(2019050719);
                      end;
                    end;
                  else
                    Message(asmr_e_invalid_reference_syntax);
                end;
                if actasmtoken<>AS_REGISTER then
                  begin
                    if hs<>'' then
                      val(hs,l,code);
                    case oper.opr.typ of
                      OPR_REFERENCE :
                        oper.opr.Ref.ScaleFactor:=l;
                      OPR_LOCAL :
                        oper.opr.localscale:=l;
                      else
                        InternalError(2019050717);
                    end;
                    if l>9 then
                      Message(asmr_e_wrong_scale_factor);
                  end;
                GotPlus:=false;
                GotStar:=false;
              end;

            AS_REGISTER :
              begin
                hreg:=actasmregister;

                Consume(AS_REGISTER, MightHaveExtension(actopcode));

                while actasmtoken in OPEXT_STARTASMTOKEN do
                begin
                  consume_voperand_ext(oper);
                end;

                if actasmtoken=AS_COLON then
                  begin
                    Consume(AS_COLON);
                    oper.InitRefConvertLocal;
                    SetSegmentOverride(oper,hreg);
                  end
                else
                  begin
                    if not((GotPlus and (not Negative)) or
                           GotStar) then
                      Message(asmr_e_invalid_reference_syntax);
                    { this register will be the index:
                       1. just read a *
                       2. next token is a *
                       3. base register is already used }
                    case oper.opr.typ of
                      OPR_LOCAL :
                        begin
                          if (oper.opr.localindexreg<>NR_NO) then
                            Message(asmr_e_multiple_index);
{$ifdef x86_64}
                          { Locals/parameters cannot be accessed RIP-relative. Need a dedicated error message here? }
                          if (hreg=NR_RIP) then
                            Message(asmr_e_no_local_or_para_allowed);
{$endif x86_64}
                          oper.opr.localindexreg:=hreg;
                          if scale<>0 then
                            begin
                              oper.opr.localscale:=scale;
                              scale:=0;
                            end;
                        end;
                      OPR_REFERENCE :
                        begin
                          if (GotStar) or
                             (actasmtoken=AS_STAR) or
                             (oper.opr.Ref.Base<>NR_NO) then
                           begin
                             if (oper.opr.Ref.Index<>NR_NO) then
                              Message(asmr_e_multiple_index);
                             oper.opr.Ref.Index:=hreg;
                             if scale<>0 then
                               begin
                                 oper.opr.Ref.ScaleFactor:=scale;
                                 scale:=0;
                               end;
                           end
                          else
                            begin
                              oper.opr.Ref.Base:=hreg;
{$ifdef x86_64}
                              { non-GOT based RIP-relative accesses are also position-independent }
                              if (oper.opr.Ref.Base=NR_RIP) and
                                 (oper.opr.Ref.RefAddr<>addr_pic) then
                                oper.opr.Ref.RefAddr:=addr_pic_no_got;
{$endif x86_64}
                            end;
                        end;
                      else
                        InternalError(2019050718);
                    end;
                    GotPlus:=false;
                    GotStar:=false;
                  end;
              end;

            AS_OFFSET :
              begin
                Consume(AS_OFFSET);
                GotOffset:=true;
              end;

            AS_TYPE,
            AS_NOT,
            AS_STRING,
            AS_INTNUM,
            AS_LPAREN : { Constant reference expression }
              begin
                if not GotPlus and not GotStar then
                  Message(asmr_e_invalid_reference_syntax);
                cse_in_flags:=[cseif_needofs,cseif_isref];
                if GotPlus and negative then
                  include(cse_in_flags,cseif_startingminus);
                BuildConstSymbolExpression(cse_in_flags,l,tempstr,tempsymtyp,size,cse_out_flags);
                { already handled by BuildConstSymbolExpression(); must be
                  handled there to avoid [reg-1+1] being interpreted as
                  [reg-(1+1)] }
                negative:=false;

                if tempstr<>'' then
                 begin
                   if GotStar then
                    Message(asmr_e_only_add_relocatable_symbol);
                   if not Assigned(oper.opr.Ref.Symbol) then
                     begin
                       oper.opr.Ref.Symbol:=CurrentAsmData.RefAsmSymbol(tempstr,tempsymtyp);

                     end
                   else
                    Message(asmr_e_cant_have_multiple_relocatable_symbols);
                 end;
                case oper.opr.typ of
                  OPR_REFERENCE :
                    begin
                      if GotStar then
                       oper.opr.Ref.ScaleFactor:=l
                      else if (prevasmtoken = AS_STAR) then
                       begin
                         if scale<>0 then
                           scale:=l*scale
                         else
                           scale:=l;
                       end
                      else
                      begin
                        Inc(oper.opr.Ref.Offset,l);
                        Inc(oper.opr.constoffset,l);
                      end;
                    end;
                  OPR_LOCAL :
                    begin
                      if GotStar then
                       oper.opr.localscale:=l
                      else if (prevasmtoken = AS_STAR) then
                       begin
                         if scale<>0 then
                           scale:=l*scale
                         else
                           scale:=l;
                       end
                      else
                        Inc(oper.opr.localsymofs,l);
                    end;
                  else
                    InternalError(2019050714);
                end;
                GotPlus:=(prevasmtoken=AS_PLUS) or
                         (prevasmtoken=AS_MINUS);
                if GotPlus then
                  negative := prevasmtoken = AS_MINUS;
                GotStar:=(prevasmtoken=AS_STAR);
              end;

            AS_LBRACKET :
              begin
                if (GotPlus and Negative) or GotStar then
                  Message(asmr_e_invalid_reference_syntax);
                tmpoper:=Tx86Operand.create;
                BuildReference(tmpoper);
                AddReferences(oper,tmpoper);
                tmpoper.Free;
                GotPlus:=false;
                GotStar:=false;
              end;

            AS_RBRACKET :
              begin
                if GotPlus or GotStar or BracketlessReference then
                  Message(asmr_e_invalid_reference_syntax);

                Consume(AS_RBRACKET, MightHaveExtension(actopcode));
                while actasmtoken in OPEXT_STARTASMTOKEN do
                begin
                  consume_voperand_ext(oper);
                end;



                if actasmtoken=AS_LBRACKET then
                  begin
                    tmpoper:=Tx86Operand.create;
                    BuildReference(tmpoper);
                    AddReferences(oper,tmpoper);
                    tmpoper.Free;
                  end;
                break;
              end;

            AS_SEPARATOR,
            AS_END,
            AS_COMMA:
              begin
                if not BracketlessReference then
                  begin
                    Message(asmr_e_invalid_reference_syntax);
                    RecoverConsume(true);
                  end;
                break;
              end;

            else
              Begin
                Message(asmr_e_invalid_reference_syntax);
                RecoverConsume(true);
                break;
              end;
          end;
        until false;
      end;
{ Disable range check because opr.val must accept values from min(longint) to max(dword) for i386 }
{$R-}
    Procedure TX86IntReader.BuildConstantOperand(oper: tx86operand);
      var
        l,size : TCGInt;
        tempstr : string;
        tempsymtyp : TAsmsymtype;
        cse_out_flags : TConstSymbolExpressionOutputFlags;
      begin
        if not (oper.opr.typ in [OPR_NONE,OPR_CONSTANT]) then
          Message(asmr_e_invalid_operand_type);
        BuildConstSymbolExpression([cseif_needofs],l,tempstr,tempsymtyp,size,cse_out_flags);

        if tempstr<>'' then
          begin
            oper.opr.typ:=OPR_SYMBOL;
            oper.opr.symofs:=l;
            oper.opr.Symbol:=CurrentAsmData.RefAsmSymbol(tempstr,tempsymtyp);
            oper.opr.symseg:=cseof_isseg in cse_out_flags;
            oper.opr.sym_farproc_entry:=cseof_is_farproc_entry in cse_out_flags;
          end
        else
          if oper.opr.typ=OPR_NONE then
            begin
              oper.opr.typ:=OPR_CONSTANT;
              oper.opr.Val:=l;
            end
          else
            inc(oper.opr.Val,l);
      end;


    Procedure TX86IntReader.BuildOperand(oper: tx86operand;istypecast:boolean);

        procedure AddLabelOperand(hl:TAsmLabel);
        begin
          if (oper.opr.typ=OPR_NONE) and
             is_calljmp(actopcode) then
           begin
             oper.opr.typ:=OPR_SYMBOL;
             oper.opr.Symbol:=hl;
           end
          else
           begin
             oper.InitRef;
             oper.opr.Ref.Symbol:=hl;
             oper.haslabelref:=true;

           end;
        end;


      var
        expr,
        hs      : string;
        tempreg : TRegister;
        l       : TCGInt;
        hl      : TAsmLabel;
        toffset,
        tsize   : TCGInt;
        hastypecast: boolean;

      begin
        oper.vopext := 0;

        expr:='';
        repeat
          if actasmtoken=AS_DOT then
            begin
              if expr<>'' then
                begin
                  BuildRecordOffsetSize(expr,toffset,tsize,hs,false,hastypecast);
                  if (oper.opr.typ<>OPR_NONE) and
                     (hs<>'') then
                    Message(asmr_e_wrong_sym_type);
                  oper.SetSize(tsize,true);
                  if hastypecast then
                    oper.hastype:=true;
                  { we have used the size of a field. Reset the typesize of the record }
                  oper.typesize:=0;
                  case oper.opr.typ of
                    OPR_LOCAL :
                      begin
                        { don't allow direct access to fields of parameters, because that
                          will generate buggy code. Allow it only for explicit typecasting
                          and when the parameter is in a register (delphi compatible) }
                        if (not oper.hastype) then
                          checklocalsubscript(oper.opr.localsym);

                        oper.opr.localforceref:=true;
                        inc(oper.opr.localsymofs,toffset);
                        oper.opr.localvarsize := tsize;
                      end;
                    OPR_CONSTANT :
                      inc(oper.opr.Val,toffset);
                    OPR_REFERENCE :
                      begin
                        inc(oper.opr.Ref.Offset,toffset);
                        oper.opr.varsize := tsize;
                      end;

                    OPR_NONE :
                      begin
                        if (hs <> '') then
                          begin
                            oper.opr.typ:=OPR_SYMBOL;
                            oper.opr.Symbol:=CurrentAsmData.RefAsmSymbol(hs,AT_FUNCTION);
                          end
                        else
                          begin
                            oper.opr.typ:=OPR_CONSTANT;
                            oper.opr.Val:=toffset;
                          end;
                      end;
                    OPR_REGISTER :
                      Message(asmr_e_invalid_reference_syntax);
                    OPR_SYMBOL:
                      Message(asmr_e_invalid_symbol_ref);
                    else
                      InternalError(200309222);
                  end;
                  expr:='';
                end
              else
                begin
                  { See it as a separator }
                  Consume(AS_DOT);
                end;
           end;

          case actasmtoken of

            AS_SEG :
              Begin
                Message(asmr_e_seg_not_supported);
                Consume(actasmtoken);
              end;

            AS_OFFSET,
            AS_SIZEOF,
            AS_VMTOFFSET,
            AS_TYPE,
            AS_NOT,
            AS_STRING,
            AS_PLUS,
            AS_MINUS,
            AS_LPAREN,
            AS_INTNUM :
              begin
                case oper.opr.typ of
                  OPR_REFERENCE :
{$ifndef x86_64}
                    { this is for the i386 scenario where you have
                        <load got into ebx>
                        mov eax, [ebx].offset globalvar

                      x86-64 uses RIP-based addresses (both for GOT and non-GOT
                      relative accesses)
                    }
                    if (actasmtoken=AS_OFFSET) and
                       (cs_create_pic in CurrentSettings.ModuleSwitches) then
                      begin
                        Consume(AS_OFFSET);
                        oper.opr.Ref.RefAddr:=addr_pic;
                        BuildOperand(oper,false);
                      end
                    else
{$endif x86_64}
                    begin
                      l := BuildRefConstExpression(tsize);
                      if tsize<>0 then
                        oper.SetSize(tsize,false);
                      inc(oper.opr.Ref.Offset,l);
                      inc(oper.opr.constoffset,l);
                    end;
                  OPR_LOCAL :
                    begin
                      l := BuildConstExpression;
                      inc(oper.opr.localsymofs,l);
                      inc(oper.opr.localconstoffset,l);
                    end;

                  OPR_NONE,
                  OPR_CONSTANT :
                    BuildConstantOperand(oper);
                  else
                    Message(asmr_e_invalid_operand_type);
                end;
              end;

            AS_PTR :
              begin
                if not oper.hastype then
                  begin
                    if (oper.opr.typ=OPR_CONSTANT) then
                      begin
                        oper.typesize:=oper.opr.Val;
                        { reset constant value of operand }
                        oper.opr.typ:=OPR_NONE;
                        oper.opr.Val:=0;
                      end
                    else
                      Message(asmr_e_syn_operand);
                  end;
                Consume(AS_PTR);
                { in delphi mode, allow e.g. call dword ptr eax,
                  see also tbs/tw18225.pas }
                if not(m_delphi in CurrentSettings.ModeSwitches) then
                  oper.InitRef;
                { if the operand subscripts a record, the typesize will be
                  rest -> save it here and restore it afterwards }
                l:=oper.typesize;
                BuildOperand(oper,false);
                oper.SetSize(l,true);
              end;

            AS_ID : { A constant expression, or a Variable ref. }
              Begin
                { Label or Special symbol reference? }
                if actasmpattern[1] = '@' then
                 Begin
                   if actasmpattern = '@RESULT' then
                    Begin
                      oper.SetupResult;
                      Consume(AS_ID);
                      expr:='result';
                    end
                   else
                    if (actasmpattern = '@CODE') or (actasmpattern = '@DATA') then
                     begin

                       Message(asmr_w_CODE_and_DATA_not_supported);

                       Consume(AS_ID);
                     end
                   else
                    { Local Label }
                    begin
                      CreateLocalLabel(actasmpattern,hl,false);
                      Consume(AS_ID);
                      AddLabelOperand(hl);
                    end;
                 end
                else
                { support result for delphi modes }
                 if (m_objpas in CurrentSettings.ModeSwitches) and (actasmpattern='RESULT') then
                  begin
                    oper.SetUpResult;
                    Consume(AS_ID);
                    expr:='result';
                  end
                { probably a variable or normal expression }
                { or a procedure (such as in CALL ID)      }
                else
                 Begin
                   { is it a constant ? }
                   if SearchIConstant(actasmpattern,l) then
                    Begin
                      case oper.opr.typ of
                        OPR_REFERENCE :
                          begin
                            l := BuildRefConstExpression(tsize);
                            if tsize<>0 then
                              oper.SetSize(tsize,false);
                            inc(oper.opr.Ref.Offset,l);
                            inc(oper.opr.constoffset,l);
                          end;

                        OPR_LOCAL :
                          begin
                            l := BuildRefConstExpression(tsize);
                            if tsize<>0 then
                              oper.SetSize(tsize,false);
                            inc(oper.opr.localsymofs,l);
                            inc(oper.opr.localconstoffset,l);
                          end;
                        OPR_NONE,
                        OPR_CONSTANT :
                          BuildConstantOperand(oper);
                        else
                          Message(asmr_e_invalid_operand_type);
                      end;
                    end
                   else
                    { Check for pascal label }
                    if SearchLabel(actasmpattern,hl,false) then
                     begin
                       Consume(AS_ID);
                       AddLabelOperand(hl);
                     end
                    else
                    { is it a normal variable ? }
                     Begin
                       expr:=actasmpattern;
                       Consume(AS_ID, MightHaveExtension(actopcode));

                       while actasmtoken in OPEXT_STARTASMTOKEN do
                       begin
                         consume_voperand_ext(oper);
                       end;


                       { typecasting? }
                       if SearchType(expr,l) then
                        begin
                          oper.hastype:=true;
                          oper.typesize:=l;
                          case actasmtoken of
                            AS_LPAREN :
                              begin
                                { Support Type([Reference]) }
                                Consume(AS_LPAREN);
                                BuildOperand(oper,true);
                                { Delphi also supports Type(Register) and
                                  interprets it the same as Type([Register]).  }
                                if (oper.opr.typ = OPR_REGISTER) then
                                  { This also sets base to the register.  }
                                  oper.InitRef;
                                Consume(AS_RPAREN);
                              end;
                            AS_LBRACKET :
                              begin
                                { Support Var.Type[Index] }
                                { Convert @label.Byte[1] to reference }
                                if oper.opr.typ=OPR_SYMBOL then
                                  oper.initref;
                              end;
                            else
                              ;
                          end;
                        end
                       else
                        begin
                          if not oper.SetupVar(expr,false) then
                            Begin
                              { not a variable, check special variables.. }
                              if expr = 'SELF' then
                                begin
                                  oper.SetupSelf;
                                  expr:='self';
                                end
                              else
                                begin
                                  Message1(sym_e_unknown_id,expr);
                                  expr:='';
                                end;
                            end;
                          { indexed access to variable? }
                          if actasmtoken=AS_LBRACKET then
                            begin
                              { ... then the operand size is not known anymore }
                              oper.Size:=OS_NO;
                              BuildReference(oper);
                            end;
                        end;
                     end;
                 end;
              end;

            AS_REGISTER : { Register, a variable reference or a constant reference }
              begin
                { save the type of register used. }
                tempreg:=actasmregister;

                Consume(AS_REGISTER, MightHaveExtension(actopcode));

                if (GetRegType(tempreg) in [R_MMREGISTER, R_ADDRESSREGISTER]) then
                 begin
                   while actasmtoken in OPEXT_STARTASMTOKEN do
                  begin
                    consume_voperand_ext(oper);
                  end;
                end;

                if actasmtoken = AS_COLON then
                 Begin
                   Consume(AS_COLON);
                   oper.InitRef;
                   SetSegmentOverride(oper,tempreg);
                   BuildReference(oper);
                 end
                else
                { Simple register }
                 begin
                   if (oper.opr.typ <> OPR_NONE) then
                     Message(asmr_e_syn_operand);
                   oper.opr.typ:=OPR_REGISTER;
                   oper.opr.reg:=tempreg;
                   oper.SetSize(TCgSize2Size[reg_cgsize(oper.opr.reg)],true);
                 end;
              end;

            AS_LBRACKET: { a variable reference, register ref. or a constant reference }
              Begin
                BuildReference(oper);
              end;

            AS_DWORD,
            AS_BYTE,
            AS_WORD,
            AS_TBYTE,
            AS_DQWORD,
            AS_QWORD,
            AS_OWORD,
            AS_XMMWORD,
            AS_YWORD,
            AS_YMMWORD,
            AS_ZWORD,
            AS_ZMMWORD
            :
              begin
                { Type specifier }
                oper.hastype:=true;
                oper.typesize:=0;
                case actasmtoken of
                  AS_DWORD : oper.typesize:=4;
                  AS_WORD  : oper.typesize:=2;
                  AS_BYTE  : oper.typesize:=1;
                  AS_QWORD : oper.typesize:=8;
                  AS_DQWORD : oper.typesize:=16;
                  AS_TBYTE : oper.typesize:=10;
                  AS_OWORD,
                  AS_XMMWORD: oper.typesize:=16;
                  AS_YWORD,
                  AS_YMMWORD: oper.typesize:=32;
                  AS_ZWORD,
                  AS_ZMMWORD: oper.typesize:=64;
                  else
                    InternalError(2010061101);
                end;
                Consume(actasmtoken);
                if (actasmtoken=AS_LPAREN) then
                  begin
                    { Support "xxx ptr [Reference]" }
                    { in case the expression subscripts a record, the typesize
                      is reset, so save the explicit size we set above }
                    l:=oper.typesize;
                    Consume(AS_LPAREN);
                    BuildOperand(oper,true);
                    Consume(AS_RPAREN);
                    oper.SetSize(l,true);
                  end;
              end;

            AS_SEPARATOR,
            AS_END,
            AS_COMMA,
            AS_COLON:
              begin
                break;
              end;

            AS_RPAREN:
              begin
                if not istypecast then
                  begin
                    Message(asmr_e_syn_operand);
                    Consume(AS_RPAREN);
                  end
                else
                  break;
              end;

            else
              begin
                Message(asmr_e_syn_operand);
                RecoverConsume(true);
                break;
              end;
          end;
        until false;



        { End of operand, update size if a typecast is forced }
        if (oper.typesize<>0) and
           (oper.opr.typ in [OPR_REFERENCE,OPR_LOCAL]) then
          oper.SetSize(oper.typesize,true);

      end;


    Procedure TX86IntReader.BuildOpCode(instr : tx86instruction);
      var
        PrefixOp,OverrideOp: TAsmOp;
        operandnum : LongInt;
        t: TRegister;
        is_far_const:boolean;
        i:byte;
        tmp: TOperand;
        di_param, si_param: ShortInt;
        prefix_or_override_pending_concat: boolean = false;

      begin
        PrefixOp:=A_None;
        OverrideOp:=A_None;
        is_far_const:=false;
        { prefix seg opcode / prefix opcode }
        repeat
          if is_prefix(actopcode) then
            with instr do
              begin
                if prefix_or_override_pending_concat then
                  ConcatInstruction(curlist);
                PrefixOp:=ActOpcode;
                opcode:=ActOpcode;
                condition:=ActCondition;
                opsize:=ActOpsize;
                prefix_or_override_pending_concat:=true;
                consume(AS_OPCODE);
              end
          else
           if is_override(actopcode) then
             with instr do
               begin
                 if prefix_or_override_pending_concat then
                   ConcatInstruction(curlist);
                 OverrideOp:=ActOpcode;
                 opcode:=ActOpcode;
                 condition:=ActCondition;
                 opsize:=ActOpsize;
                 prefix_or_override_pending_concat:=true;
                 consume(AS_OPCODE);
               end
          else
            break;
          { allow for newline after prefix or override }
          while actasmtoken=AS_SEPARATOR do
            consume(AS_SEPARATOR);
        until (actasmtoken<>AS_OPCODE);
        { opcode }
        if (actasmtoken <> AS_OPCODE) then
         begin
           { allow a prefix or override to be used standalone, like an opcode
             with zero operands; this is TP7 compatible and allows compiling
             ugly code like 'seges; db $67,$66; lodsw' }
           if prefix_or_override_pending_concat then
             exit
           else
             begin
               Message(asmr_e_invalid_or_missing_opcode);
               RecoverConsume(false);
               exit;
             end;
         end;
        if prefix_or_override_pending_concat then
          begin
            instr.ConcatInstruction(curlist);
            prefix_or_override_pending_concat:=false;
          end;
        { Fill the instr object with the current state }
        with instr do
          begin
            Opcode:=ActOpcode;
            condition:=ActCondition;
            opsize:=ActOpsize;

            { Valid combination of prefix/override and instruction ?  }
            if (prefixop<>A_NONE) and (NOT CheckPrefix(PrefixOp,actopcode)) then
              Message1(asmr_e_invalid_prefix_and_opcode,actasmpattern);
            if (overrideop<>A_NONE) and (NOT CheckOverride(OverrideOp,ActOpcode)) then
              Message1(asmr_e_invalid_override_and_opcode,actasmpattern);
          end;
        { pushf/popf/pusha/popa have to default to 16 bit in Intel mode
          (Intel manual and Delphi-compatible) -- setting the opsize for
          these instructions doesn't change anything in the internal assember,
          so change the opcode }
        if (instr.opcode=A_POPF) then
          instr.opcode:=A_POPFW
        else if (instr.opcode=A_PUSHF) then
          instr.opcode:=A_PUSHFW
{$ifndef x86_64}
        else if (instr.opcode=A_PUSHA) then
          instr.opcode:=A_PUSHAW
        else if (instr.opcode=A_POPA) then
          instr.opcode:=A_POPAW
{$endif x86_64}

        ;
        { We are reading operands, so opcode will be an AS_ID }
        { process operands backwards to get them in AT&T order }
        operandnum:=max_operands;
        is_far_const:=false;
        Consume(AS_OPCODE);
        { Zero operand opcode ?  }
        if actasmtoken in [AS_SEPARATOR,AS_END] then
          exit;
        { Read Operands }
        repeat
          case actasmtoken of
            { End of asm operands for this opcode }
            AS_END,
            AS_SEPARATOR :
              break;

            { Operand delimiter }
            AS_COMMA :
              begin
                { should have something before the comma }
                if instr.operands[operandnum].opr.typ=OPR_NONE then
                  Message(asmr_e_syntax_error);
                if operandnum <= 1 then
                  Message(asmr_e_too_many_operands)
                else
                  Dec(operandnum);
                Consume(AS_COMMA,instr.MightHaveExtension);
              end;

            {Far constant, i.e. jmp $0000:$11111111.}
            AS_COLON:
              begin
                is_far_const:=true;
                if operandnum<max_operands then
                  message(asmr_e_too_many_operands)
                else
                  dec(operandnum);
                consume(AS_COLON);
              end;

            { Type specifier }
            AS_NEAR,
            AS_FAR :
              begin
                if actasmtoken = AS_NEAR then
                  begin

                    Message(asmr_w_near_ignored);

                    instr.opsize:=S_NEAR;
                  end
                else
                  begin

                    Message(asmr_w_far_ignored);

                    instr.opsize:=S_FAR;
                  end;
                Consume(actasmtoken);
                if actasmtoken=AS_PTR then
                 begin
                   Consume(AS_PTR);
                   instr.Operands[operandnum].InitRef;
                 end;
                BuildOperand(instr.Operands[operandnum] as tx86operand,false);
              end;
            AS_LOPSAE,
            AS_LOPER:
              if operandnum < max_operands then
               begin
                 consume_voperand_ext(instr.Operands[operandnum + 1] as tx86operand, false);
                 if actasmtoken in [AS_OPSAE,AS_OPRNSAE,AS_OPRDSAE,AS_OPRUSAE,AS_OPRZSAE] then
                  begin
                    consume(actasmtoken);
                    // ignore operand
                    if actasmtoken in [AS_END,AS_SEPARATOR,AS_COMMA] then inc(operandnum)
                     else Message(asmr_e_syntax_error);
                  end
                   else Message(asmr_e_syntax_error);
               end
                else Message(asmr_e_syntax_error);
            else
              BuildOperand(instr.Operands[operandnum] as tx86operand,false);
          end; { end case }
        until false;

        { shift operands to start from 1, exchange to make sure they are destroyed correctly }
        for i:=operandnum to max_operands do
          begin
            tmp:=instr.operands[i+1-operandnum];
            instr.operands[i+1-operandnum]:=instr.operands[i];
            instr.operands[i]:=tmp;
          end;
        operandnum:=(max_operands+1)-operandnum;
        instr.ops:=operandnum;
        { Check operands }
        for i:=1 to operandnum do
          begin
            if is_far_const and
               (instr.operands[i].opr.typ<>OPR_CONSTANT) then
              message(asmr_e_expr_illegal)
            else
              if instr.operands[i].opr.typ=OPR_NONE then
                Message(asmr_e_syntax_error);
          end;
        { Check for invalid ES: overrides }
        if is_x86_parameterized_string_op(instr.opcode) then
          begin
            si_param:=get_x86_string_op_si_param(instr.opcode);
            if si_param<>-1 then
              si_param:=x86_parameterized_string_op_param_count(instr.opcode)-si_param;
            di_param:=get_x86_string_op_di_param(instr.opcode);
            if di_param<>-1 then
              begin
                di_param:=x86_parameterized_string_op_param_count(instr.opcode)-di_param;
                if di_param<=operandnum then
                  with instr.operands[di_param] do
                    if (opr.typ=OPR_REFERENCE) and
                       (opr.Ref.Segment<>NR_NO) and
                       (opr.Ref.Segment<>NR_ES) then
                      Message(asmr_e_cannot_override_es_segment);
              end;
            { if two memory parameters, check whether their address sizes are equal }
            if (si_param<>-1) and (di_param<>-1) and
               (si_param<=operandnum) and (di_param<=operandnum) and
               (instr.operands[si_param].opr.typ=OPR_REFERENCE) and
               (instr.operands[di_param].opr.typ=OPR_REFERENCE) then
              begin
                if get_ref_address_size(instr.operands[si_param].opr.Ref)<>
                   get_ref_address_size(instr.operands[di_param].opr.Ref) then
                  Message(asmr_e_address_sizes_do_not_match);
              end;
          end;
        { e.g. for "push dword 1", "push word 6" }
        if (instr.ops=1) and
           (instr.operands[1].typesize<>0) then
          instr.operands[1].SetSize(instr.operands[1].typesize,false);

        if (MemRefInfo(instr.opcode).ExistsSSEAVX) and
           (MemRefInfo(instr.opcode).MemRefSize in MemRefSizeInfoVMems) then
        begin
          for i:=1 to operandnum do
          begin
            if (instr.operands[i].opr.typ = OPR_REFERENCE) and
               (GetRegType(instr.operands[i].opr.Ref.Base) = R_MMREGISTER) and
               (instr.operands[i].opr.Ref.Index = NR_NO) then
            begin
              instr.operands[i].opr.Ref.Index := instr.operands[i].opr.Ref.Base;
              instr.operands[i].opr.Ref.Base  := NR_NO;
            end
            else if (instr.operands[i].opr.typ = OPR_REFERENCE) and
                    (GetRegType(instr.operands[i].opr.Ref.Base) = R_MMREGISTER) and
                    (GetRegType(instr.operands[i].opr.Ref.Index) = R_INTREGISTER) and
                    (GetSubReg(instr.operands[i].opr.Ref.Index) = R_SUBADDR) then
            begin
              // exchange base- and index-register
              // e.g. VGATHERDPD  XMM0, [XMM1 + RAX], XMM2 =>> VGATHERDPD  XMM0, [RAX + XMM1], XMM2
              // e.g. VGATHERDPD  XMM0, [XMM1 + RAX * 2], XMM2 =>> not supported
              // e.g. VGATHERDPD  XMM0, [XMM1 + RAX + 16], XMM2 =>> VGATHERDPD  XMM0, [RAX + XMM1 + 16]
              if instr.operands[i].opr.Ref.ScaleFactor > 1 then Message(asmr_e_invalid_reference_syntax)
              else
              begin
                t := instr.operands[i].opr.Ref.Base;
                instr.operands[i].opr.Ref.Base := instr.operands[i].opr.Ref.Index;
                instr.operands[i].opr.Ref.Index := t;
              end;
            end;
          end;
        end;
      end;


    Procedure TX86IntReader.BuildConstant(constsize: byte);
      var
        asmsymtyp : TAsmsymtype;
        asmsym,
        expr: string;
        value,size : TCGInt;
        cse_out_flags : TConstSymbolExpressionOutputFlags;
      Begin
        Repeat
          Case actasmtoken of
            AS_STRING:
              Begin
                { DD and DW cases }
                if constsize <> 1 then
                 Begin
                   if Not PadZero(actasmpattern,constsize) then
                    Message(scan_f_string_exceeds_line);
                 end;
                expr:=actasmpattern;
                Consume(AS_STRING);
                Case actasmtoken of
                  AS_COMMA:
                    Consume(AS_COMMA);
                  AS_END,
                  AS_SEPARATOR: ;
                  else
                    Message(asmr_e_invalid_string_expression);
                end;
                ConcatString(curlist,expr);
              end;
            AS_BYTE,
            AS_WORD,
            AS_DWORD,
            AS_TBYTE,
            AS_DQWORD,
            AS_QWORD,
            AS_OWORD,
            AS_XMMWORD,
            AS_YWORD,
            AS_YMMWORD,
            AS_PLUS,
            AS_MINUS,
            AS_LPAREN,
            AS_NOT,
            AS_INTNUM,
            AS_OFFSET,
            AS_LBRACKET,

            AS_ID :
              Begin
                BuildConstSymbolExpression([cseif_referencelike],value,asmsym,asmsymtyp,size,cse_out_flags);
                if asmsym<>'' then
                 begin
                   if not (cseof_isseg in cse_out_flags) and

                      (constsize<>sizeof(PInt))

                      then
                     begin
                       Message1(asmr_w_const32bit_for_address,asmsym);
                       constsize:=sizeof(PInt);
                     end;

                     ConcatConstSymbol(curlist,asmsym,'',asmsymtyp,value,constsize,cseof_hasofs in cse_out_flags);
                 end
                else
                 ConcatConstant(curlist,value,constsize);
              end;
            AS_COMMA:
              begin
                Consume(AS_COMMA);
              end;
            AS_ALIGN,
            AS_DB,
            AS_DW,
            AS_DD,
            AS_DQ,
            AS_OPCODE,
            AS_END,
            AS_SEPARATOR:
              break;
            else
              begin
                Message(asmr_e_syn_constant);
                RecoverConsume(false);
              end
          end;
        Until false;
      end;


  function TX86IntReader.Assemble: TLinkedList;
    Var
      hl : TAsmLabel;
      instr : Tx86Instruction;
      tmpsym: TSym;
      tmpsrsymtable: TSymTable;
    Begin
      Message1(asmr_d_start_reading,'intel');
      inexpression:=FALSE;
      firsttoken:=TRUE;
     { sets up all opcode and register tables in uppercase
       done in the constructor now
      if not _asmsorted then
       Begin
         SetupTables;
         _asmsorted:=TRUE;
       end;
      }
      curlist:=TAsmList.Create;
      { we might need to know which parameters are passed in registers }
      if not parse_generic then
        CurrentProcInfo.generate_parameter_info;
      { start tokenizer }
      gettoken;
      { main loop }
      repeat
        case actasmtoken of
          AS_LLABEL:
            Begin
              if CreateLocalLabel(actasmpattern,hl,true) then
                ConcatLabel(curlist,hl);
              Consume(AS_LLABEL);
            end;

          AS_LABEL:
            Begin
              if SearchLabel(upper(actasmpattern),hl,true) then
                begin
                  if hl.is_public then
                    ConcatPublic(curlist,actasmpattern_origcase);
                  ConcatLabel(curlist,hl);
                end
              else
               Message1(asmr_e_unknown_label_identifier,actasmpattern);
              Consume(AS_LABEL);
            end;

          AS_DW :
            Begin
              inexpression:=true;
              Consume(AS_DW);
              BuildConstant(2);
              inexpression:=false;
            end;

          AS_DB :
            Begin
              inexpression:=true;
              Consume(AS_DB);
              BuildConstant(1);
              inexpression:=false;
            end;

          AS_DD :
            Begin
              inexpression:=true;
              Consume(AS_DD);
              BuildConstant(4);
              inexpression:=false;
            end;

{$ifdef cpu64bitaddr}
          AS_DQ:
            Begin
              inexpression:=true;
              Consume(AS_DQ);
              BuildConstant(8);
              inexpression:=false;
            end;
{$endif cpu64bitaddr}

          AS_PUBLIC:
            Begin
              Consume(AS_PUBLIC);
              repeat
                if actasmtoken=AS_ID then
                  begin
                    if (actasmpattern<>'') and (actasmpattern[1]='@') then
                      Message1(asmr_e_local_label_cannot_be_declared_public,actasmpattern)
                    else if SearchLabel(upper(actasmpattern),hl,false) then
                      begin
                        if not hl.is_public then
                          begin
                            hl.is_public:=true;
                            asmsearchsym(upper(actasmpattern),tmpsym,tmpsrsymtable);
                            if TLabelSym(tmpsym).defined then
                              Message1(asmr_e_public_must_be_used_before_label_definition,actasmpattern);
                          end;
                      end
                    else
                      Message1(asmr_e_unknown_label_identifier,actasmpattern);
                  end;
                Consume(AS_ID);
                if actasmtoken=AS_COMMA then
                  begin
                    Consume(AS_COMMA);
                    if actasmtoken<>AS_ID then
                      Consume(AS_ID);
                  end;
              until actasmtoken=AS_SEPARATOR;
            end;

          AS_ALIGN:
            Begin
              Consume(AS_ALIGN);
              ConcatAlign(curlist,BuildConstExpression);
              if actasmtoken<>AS_SEPARATOR then
                Consume(AS_SEPARATOR);
            end;

          AS_OPCODE :
            Begin
              instr:=Tx86Instruction.Create(Tx86Operand);
              BuildOpcode(instr);
              with instr do
                begin
                  CheckNonCommutativeOpcodes;
                  AddReferenceSizes;
                  SetInstructionOpsize;
                  CheckOperandSizes;
                  ConcatInstruction(curlist);
                end;
              instr.Free;
            end;

          AS_SEPARATOR :
            Begin
              Consume(AS_SEPARATOR);
            end;

          AS_TARGET_DIRECTIVE:
            HandleTargetDirective;

          AS_END :
            break; { end assembly block }

          else
            Begin
              Message(asmr_e_syntax_error);
              RecoverConsume(false);
            end;
        end; { end case }
      until false;
      { check that all referenced local labels are defined }
      checklocallabels;
      { Return the list in an asmnode }
      assemble:=curlist;
      Message1(asmr_d_finish_reading,'intel');
    end;


end.
