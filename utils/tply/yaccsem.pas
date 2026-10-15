{
  Semantic routines for the Yacc parser.


  Copyright (c) 1990-92  Albert Graef <ag@muwiinfa.geschichte.uni-mainz.de>
  Copyright (C) 1996     Berend de Boer <berend@pobox.com>

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


$Revision: 1.2 $
$Modtime: 96-08-01 6:03 $

$History: YACCSEM.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit YaccSem;

interface


var

ActPrec : Integer;
  (* active precedence level in token and precedence declarations (0 in
     %token declaration) *)
ActType : Integer;
  (* active type tag in token, precedence and type declarations *)

procedure yyerror ( Msg : String );
  (* YaccLib.yyerror redefined to ignore 'syntax error' message; the parser
     does its own error handling *)

function Sym ( K : Integer ) : Integer;
  (* returns internal symbol number for the symbol k; if k is yet undefined,
     a new nonterminal or literal symbol is created, according to the
     appearance of symbol k (nonterminal if an ordinary identifier, literal
     otherwise) *)

function NTSym ( K : Integer ) : Integer;
  (* like sym, but requires symbol k to be a nonterminal symbol; if it
     is already defined a literal, an error message is issued, and a dummy
     nonterminal symbol returned *)

function LitSym ( K : Integer; N : Integer ) : Integer;
  (* same for literal symbols; if n>0 it denotes the literal number to be
     assigned to the symbol; when a new literal identifier is defined, a
     corresponding constant definition is also written to the definition
     file *)

procedure NextSection;
  (* find next section mark (%%) in code template *)

procedure Definitions;
  (* if necessary, write out definition of the semantic value type YYSType *)

procedure CopyCode;
  (* copy Turbo Pascal code section ( %{ ... %} ) to output file *)

procedure CopyAction;
  (* copy an action to the output file *)

procedure CopySingleAction;
  (* like copy_action, but action must be single statement terminated
     with `;' *)

procedure CopyRestOfFile;
  (* copies the rest of the source file to the output file *)

procedure StartRule ( Sym : Integer );
  (* start a new rule with lhs nonterminal symbol sym *)

procedure StartBody;
  (* start a new rule body (rhs) *)

procedure EndBody;
  (* end a rule body *)

procedure AddSymbol ( Sym : Integer );
  (* add the denoted symbol to the current rule body *)

procedure AddAction;
  (* add an action to the current rule body *)

procedure AddRulePrec ( Sym : Integer );
  (* add the precedence of terminal symbol sym to the current rule *)

procedure GenerateParser;
  (* generate the parse table *)

implementation

uses YaccBase, YaccTabl, YaccClos, YaccLR0, YaccLook,
  YaccPars, YaccMsgs;

procedure yyerror ( Msg : String );
  begin
    if Msg='syntax error' then
      (* ignore *)
    else
      Fatal(Msg)
  end(*yyerror*);

function ActChar : Char;
  begin
    if CNo>Length(Line) then
      if EOF(YYIn) then
        ActChar := #0
      else
        ActChar := NL
    else
      ActChar := Line[CNo]
  end(*act_char*);

function LookaheadChar : Char;
  begin
    if Succ(CNo)>Length(Line) then
      if EOF(YYIn) then
        LookaheadChar := #0
      else
        LookaheadChar := NL
    else
      LookaheadChar := Line[Succ(CNo)]
  end(*lookahead_char*);

procedure NextChar;
  begin
    if CNo>Length(Line) then
      if EOF(YYIn) then
        { nop }
      else
        begin
          ReadLn(YYIn, Line);
          Inc(LNo); CNo := 1
        end
    else
      Inc(CNo)
  end(*next_char*);

var

(* Current rule: *)

ActRule      : TRuleRec;

(* Actions: *)

NAct : Integer;
PAct : Boolean;

function Sym ( K : Integer ) : Integer;
  var S : Integer;
  begin
    if IsDefKey(K, S) then
      Sym := S
    else if SymTable^[K].Pname^[1]='''' then
      begin
        S := NewLit;
        DefKey(K, S);
        Sym := S;
      end
    else
      begin
        S := NewNT;
        DefKey(K, S);
        Sym := S;
      end
  end(*sym*);

function NTSym ( K : Integer ) : Integer;
  var S : Integer;
  begin
    if IsDefKey(K, S) then
      if S<0 then
        NTSym := S
      else
        begin
          Error(NonTermExpected);
          NTSym := -1;
        end
    else if SymTable^[K].Pname^[1]='''' then
      begin
        Error(NonTermExpected);
        NTSym := -1;
      end
    else
      begin
        S := NewNT;
        DefKey(K, S);
        NTSym := S;
      end
  end(*ntsym*);

function LitSym ( K : Integer; N : Integer ) : Integer;
  var S : Integer;
  begin
    if IsDefKey(K, S) then
      if S>=0 then
        begin
          if N>0 then Error(DoubleTokenNumDef);
          LitSym := S;
        end
      else
        begin
          Error(LiteralExpected);
          LitSym := 1;
        end
    else if SymTable^[K].Pname^[1]='''' then
      begin
        if N>0 then
          begin
            AddLit(N);
            S := N;
          end
        else
          S := NewLit;
        DefKey(K, S);
        LitSym := S;
      end
    else
      begin
        if N>0 then
          begin
            AddLit(N);
            S := N;
          end
        else
          S := NewLit;
        DefKey(K, S);
        WriteLn(YYOut, 'const ', Pname(S), ' = ', S, ';');
        LitSym := S;
      end;
  end(*litsym*);

procedure NextSection;
  var Line : String;
  begin
    while not EOF(YYCod) do
      begin
        ReadLn(YYCod, Line);
        if Line='%%' then Exit;
        WriteLn(YYOut, Line);
      end;
  end(*next_section*);

procedure Definitions;
  var I : Integer;
  begin
    if NTypes>0 then
      begin
        WriteLn(YYOut);
        WriteLn(YYOut, 'type YYSType = record case Integer of');
        for I := 1 to NTypes do
          WriteLn(YYOut, ' ':15, I:3, ' : ( ',
                         'yy', SymTable^[TypeTable^[I]].Pname^, ' : ',
                         SymTable^[TypeTable^[I]].Pname^, ' );');
        WriteLn(YYOut, ' ':15, 'end(*YYSType*);');
      end;
  end(*definitions*);

procedure CopyCode;
  var StrState : Boolean;
  begin
    StrState := False;
    while ActChar<>#0 do
      if ActChar=NL then
        begin
          WriteLn(YYOut);
          NextChar;
        end
      else if ActChar='''' then
        begin
          Write(YYOut, '''');
          StrState := not StrState;
          NextChar;
        end
      else if not StrState and (ActChar='%') and (LookaheadChar='}') then
        Exit
      else
        begin
          Write(YYOut, ActChar);
          NextChar;
        end;
  end(*copy_code*);

procedure ScanVal;
  (* process a $ value in an action
     (not very pretty, but it does its job) *)
  var Tag, NumStr : String; I, Code : Integer;
  begin
    TokLeng := 0;
    NextChar;
    if ActChar='<' then
      begin
        (* process type tag: *)
        NextChar;
        Tag := '';
        while (ActChar<>NL) and (ActChar<>#0) and (ActChar<>'>') do
          begin
            Tag := Tag+ActChar;
            NextChar;
          end;
        if ActChar='>' then
          begin
            if not SearchType(Tag) then
              begin
                TokLeng := Length(Tag);
                Error(UnknownIdentifier);
              end;
            NextChar;
          end
        else
          Error(SyntaxError);
      end
    else
      Tag := '';
    TokLeng := 0;
    if ActChar='$' then
      begin
        (* left-hand side value: *)
        Write(YYOut, 'yyval');
        (* check for value type: *)
        if (Tag='') and (NTypes>0) then with ActRule do
          if SymType^[LHSSym]>0 then
            Tag := SymTable^[SymType^[LHSSym]].Pname^
          else
            begin
              TokLeng := 1;
              Error(TypeError);
            end;
        if Tag<>'' then Write(YYOut, '.yy', Tag);
        NextChar;
      end
    else
      begin
        (* right-hand side value: *)
        if ActChar='-' then
          begin
            NumStr := '-';
            NextChar;
          end
        else
          NumStr := '';
        while ('0'<=ActChar) and (ActChar<='9') do
          begin
            NumStr := NumStr+ActChar;
            NextChar;
          end;
        if NumStr<>'' then
          begin
            Val(NumStr, I, Code);
            if Code=0 then
              if I<=ActRule.RHSLen then
                begin
                  Write(YYOut, 'YYV[YYSP-', ActRule.RHSLen-I, ']');
                  (* check for value type: *)
                  if (Tag='') and (NTypes>0) then with ActRule do
                    if I<=0 then
                      begin
                        TokLeng := Length(NumStr)+1;
                        Error(TypeError);
                      end
                    else if SymType^[RHSSym[I]]>0 then
                      Tag := SymTable^[SymType^[RHSSym[I]]].Pname^
                    else
                      begin
                        TokLeng := Length(NumStr)+1;
                        Error(TypeError);
                      end;
                  if Tag<>'' then Write(YYOut, '.yy', Tag);
                end
              else
                begin
                  TokLeng := Length(NumStr);
                  Error(RangeError);
                end
            else
              Error(SyntaxError)
          end
        else
          Error(SyntaxError)
      end
  end(*scan_val*);

procedure CopyAction;
  var StrState : Boolean;
  begin
    StrState := False;
    while ActChar=' ' do NextChar;
    Write(YYOut, ' ':9);
    while ActChar<>#0 do
      if ActChar=NL then
        begin
          WriteLn(YYOut);
          NextChar;
          while ActChar=' ' do NextChar;
          Write(YYOut, ' ':9);
        end
      else if ActChar='''' then
        begin
          Write(YYOut, '''');
          StrState := not StrState;
          NextChar;
        end
      else if not StrState and (ActChar='}') then
        begin
          WriteLn(YYOut);
          Exit;
        end
      else if not StrState and (ActChar='$') then
        ScanVal
      else
        begin
          Write(YYOut, ActChar);
          NextChar;
        end;
  end(*copy_action*);

procedure CopySingleAction;
  var StrState : Boolean;
  begin
    StrState := False;
    while ActChar=' ' do NextChar;
    Write(YYOut, ' ':9);
    while ActChar<>#0 do
      if ActChar=NL then
        begin
          WriteLn(YYOut);
          NextChar;
          while ActChar=' ' do NextChar;
          Write(YYOut, ' ':9);
        end
      else if ActChar='''' then
        begin
          Write(YYOut, '''');
          StrState := not StrState;
          NextChar;
        end
      else if not StrState and (ActChar=';') then
        begin
          WriteLn(YYOut, ';');
          Exit;
        end
      else if not StrState and (ActChar='$') then
        ScanVal
      else
        begin
          Write(YYOut, ActChar);
          NextChar;
        end;
  end(*copy_single_action*);

procedure CopyRestOfFile;
  begin
    while ActChar<>#0 do
      if ActChar=NL then
        begin
          WriteLn(YYOut);
          NextChar;
        end
      else
        begin
          Write(YYOut, ActChar);
          NextChar;
        end;
  end(*copy_rest_of_file*);

procedure StartRule ( Sym : Integer );
  begin
    if NRules=0 then
      begin
        (* fix start nonterminal of the grammar: *)
        if StartNT=0 then StartNT := Sym;
        (* add augmented start production: *)
        with ActRule do
          begin
            LHSSym := -1;
            RHSLen := 2;
            RHSSym[1] := StartNT;
            RHSSym[2] := 0; (* end marker *)
          end;
        AddRule(NewRuleRec(ActRule));
      end;
    ActRule.LHSSym := Sym;
  end(*start_rule*);

procedure StartBody;
  begin
    ActRule.RHSLen := 0;
    PAct := False;
    WriteLn(YYOut, NRules:4, ' : begin');
  end(*start_body*);

procedure EndBody;
  begin
    if not PAct and (ActRule.RHSLen>0) then
      (* add default action: *)
      WriteLn(YYOut, ' ':9, 'yyval := YYV[YYSP-',
                            ActRule.RHSLen-1, '];');
    AddRule(NewRuleRec(ActRule));
    WriteLn(YYOut, ' ':7, 'end;');
  end(*end_body*);

procedure AddRuleAction;
  (* process an action inside a rule *)
  var K : Integer; R : TRuleRec;
  begin
    WriteLn(YYOut, ' ':7, 'end;');
    Inc(NAct);
    K := GetKey('$$'+IntStr(NAct));
    with R do
      begin
        LHSSym := NewNT;
        DefKey(K, LHSSym);
        RHSLen := 0;
      end;
    with ActRule do
      begin
        Inc(RHSLen);
        if RHSLen>MaxRuleLen then Fatal(RuleTableOverflow);
        RHSSym[RHSLen] := R.LHSSym;
      end;
    AddRule(NewRuleRec(R));
    RulePrec^[NRules+1] := RulePrec^[NRules];
    RulePrec^[NRules] := 0;
    WriteLn(YYOut, NRules:4, ' : begin');
  end(*add_rule_action*);

procedure AddSymbol ( Sym : Integer );
  begin
    if PAct then AddRuleAction;
    PAct := False;
    with ActRule do
      begin
        Inc(RHSLen);
        if RHSLen>MaxRuleLen then Fatal(RuleTableOverflow);
        RHSSym[RHSLen] := Sym;
        if Sym>=0 then RulePrec^[NRules+1] := SymPrec^[Sym]
      end
  end(*add_symbol*);

procedure AddAction;
  begin
    if PAct then AddRuleAction;
    PAct := True;
  end(*add_action*);

procedure AddRulePrec ( Sym : Integer );
  begin
    RulePrec^[NRules+1] := SymPrec^[Sym];
  end(*add_rule_prec*);

procedure GenerateParser;
  begin
    if StartNT=0 then Error(EmptyGrammar);
    if Errors=0 then
      begin
        Write('sort ... ');
        SortRules; RuleOffsets;
        Write('closures ... ');
        Closures;
        Write('first sets ... ');
        FirstSets;
        Write('LR0 set ... ');
        LR0Set;
        Write('lookaheads ... ');
        Lookaheads;
        WriteLn;
        Write('code generation ... ');
        ParseTable;
      end;
  end(*generate_parser*);

begin
  NAct := 0;
end(*YaccSem*).
