{
  Parser for Lex grammar rules.

  This module implements a parser for Lex grammar rules. It should
  probably be reimplemented using Lex and Yacc, but the irregular
  lexical structure of the Lex language makes that rather tedious,
  so I decided to use a conventional recursive-descent-parser
  instead.


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


$Revision: 1.4 $
$Modtime: 96-08-01 6:30 $

$History: LEXRULES.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit LexRules;

interface

uses LexBase, LexTable;


procedure ParseRule ( RuleNo : Integer );
  (* rule parser (rule_no=number of parsed rule) *)

(* Return values of rule parser: *)

var

Expr, Stmt : String;
  (* expression and statement part of rule *)
Cf   : Boolean;
  (* caret flag *)
NSt : Integer;
  (* number of start states in prefix *)
St   : array [1..MaxStates] of Integer;
  (* start states *)
R    : PRegExpr;
  (* parsed expression *)

implementation

uses LexMsgs;

(* Scanner routines:

   The following routines provide access to the source line and handle
   macro substitutions. To perform macro substitution, an input buffer
   is maintained which contains the rest of the line to be parsed, plus
   any pending macro substitutions. The input buffer is organized as
   a stack onto which null-terminated replacement strings are pushed
   as macro substitutions are processed (the terminating null-character
   is used as an endmarker for macros, in order to keep track of the
   number of pending macro substitutions); characters are popped from the
   stack via calls to the get_char routine.

   In order to perform macro substitution, the scanner also has to
   maintain some state information to be able to determine when it
   is scanning quoted characters, strings or character classes (s.t.
   no macro substitution is performed in such cases).

   The scanner also keeps track of the current source line position in
   variable act_pos; if there are any macro substitutions on the stack,
   act_pos will point to the position of the original macro call in the
   source line. This is needed to give proper error diagnostics. *)

const MaxChars = 2048;

var

ActPos, BufPtr : Integer;
  (* current position in source line and input stack pointer *)
Buf : array [1..MaxChars] of Char;
  (* input buffer *)
StrState, CClassState, QuoteState : Boolean;
  (* state information *)
NMacros : Integer;
  (* number of macros currently on stack *)

procedure MarkError ( Msg : String; Offset : Integer );
  (* mark error position (offset=offset of error position (to the left of
     act_pos) *)
  begin
    if NMacros=0 then
      Error(Msg, ActPos-Offset)
    else
      Error(Msg+' in regular definition', ActPos)
  end(*mark_error*);

procedure PutStr(Str : String);
  (* push str onto input stack *)
  var I : Integer;
  begin
    Inc(BufPtr, Length(Str));
    if BufPtr>MaxChars then Fatal(MacroStackOverflow);
    for I := 1 to Length(Str) do
      Buf[BufPtr-I+1] := Str[I];
  end(*put_str*);

procedure InitScanner;
  (* initialize the scanner *)
  begin
    ActPos := 1; BufPtr := 0;
    StrState := False; CClassState := False; QuoteState := False;
    NMacros := 0;
    PutStr(Line);
  end(*init_scanner*);

function ActChar : Char;
  (* current character (#0 if none) *)
  function PushMacro : Boolean;
    (* check for macro call at current position in input buffer *)
    function ScanMacro ( var Name : String ) : Boolean;
      var I : Integer;
      begin
        if (BufPtr>1) and
           (Buf[BufPtr]='{') and (Buf[BufPtr-1] in Letters) then
          begin
            Name := '{'; I := BufPtr-1;
            while (I>0) and (Buf[I] in Alphanums) do
              begin
                Name := Name+Buf[I];
                Dec(I);
              end;
            if (I>0) and (Buf[I]='}') then
              begin
                ScanMacro := True;
                Name := Name+'}';
                BufPtr := I-1;
              end
            else
              begin
                ScanMacro := False;
                MarkError(SyntaxError, -Length(Name));
                BufPtr := I;
              end
          end
        else
          ScanMacro := False
      end(*scan_macro*);
    var Name : String;
    begin
      if ScanMacro(Name) then
        begin
          PushMacro := True;
{$ifdef fpc}
          with SymTable^[Key(Name, MaxKeys, @Lookup, @Entry)] do
{$else}
          with SymTable^[Key(Name, MaxKeys, Lookup, Entry)] do
{$endif}
            if SymType=MacroSym then
              begin
                PutStr(Subst^+#0);
                Inc(NMacros);
              end
            else
              MarkError(UndefinedSymbol, -1)
        end
      else
        PushMacro := False
    end(*push_macro*);
  function PopMacro : Boolean;
    (* check for macro endmarker *)
    begin
      if (BufPtr>0) and (Buf[BufPtr]=#0) then
        begin
          Dec(BufPtr);
          Dec(NMacros);
          if NMacros=0 then ActPos := Length(Line)-BufPtr+1;
          PopMacro := True;
        end
      else
        PopMacro := False
    end(*pop_macro*);
  begin
    if not (StrState or CClassState or QuoteState) then
      while PushMacro do while PopMacro do ;
    if BufPtr=0 then
      ActChar := #0
    else
      begin
        while PopMacro do ;
        if (BufPtr>0) then
          ActChar := Buf[BufPtr]
        else
          ActChar:=#0;
      end
  end(*act_char*);

procedure GetChar;
  (* get next character *)
  begin
    if BufPtr>0 then
      begin
        case Buf[BufPtr] of
          '\' : QuoteState := not QuoteState;
          '"' : if QuoteState then
                  QuoteState := False
                else if not CClassState then
                  StrState := not StrState;
          '[' : if QuoteState then
                  QuoteState := False
                else if not StrState then
                  CClassState := True;
          ']' : if QuoteState then
                  QuoteState := False
                else if not StrState then
                  CClassState := False;
          else  QuoteState := False;
        end;
        Dec(BufPtr);
        if NMacros=0 then
          ActPos := Length(Line)-BufPtr+1;
      end
  end(*get_char*);

(* Semantic routines: *)

procedure AddStartState ( Symbol : String );
  (* add start state to st array *)
  begin
{$ifdef fpc}
    with SymTable^[Key(Symbol, MaxKeys, @Lookup, @Entry)] do
{$else}
    with SymTable^[Key(Symbol, MaxKeys, Lookup, Entry)] do
{$endif}
      if SymType=StartStateSym then
        begin
          if NSt>=MaxStartStates then Exit; { this shouldn't happen }
          Inc(NSt);
          St[NSt] := StartState;
        end
      else
        MarkError(UndefinedSymbol, Length(Symbol))
  end(*add_start_state*);

(* Parser: *)

procedure ParseRule ( RuleNo : Integer );

  procedure Rule ( var Done : Boolean );

    (* parse rule according to syntax:

       rule                     : start_state_prefix caret
                                  expr [ '$' | '/' expr ]
                                ;

       start_state_prefix       : /* empty */
                                | '<' start_state_list '>'
                                ;

       start_state_list         : ident { ',' ident }
                                ;

       caret                    : /* empty */
                                | '^'
                                ;

       expr                     : term { '|' term }
                                ;

       term                     : factor { factor }
                                ;

       factor                   : char
                                | string
                                | cclass
                                | '.'
                                | '(' expr ')'
                                | factor '*'
                                | factor '+'
                                | factor '?'
                                | factor '{' num [ ',' num ] '}'
                                ;
    *)

    procedure StartStatePrefix ( var Done : Boolean );
      procedure StartStateList ( var Done : Boolean );
        procedure Ident ( var Done : Boolean );
          var IDStr : String;
          begin(*ident*)
            Done := ActChar in Letters;   if not Done then Exit;
            IDStr := ActChar;
            GetChar;
            while ActChar in Alphanums do
              begin
                IDStr := IDStr+ActChar;
                GetChar;
              end;
            AddStartState(IDStr);
          end(*ident*);
        begin(*start_state_list*)
          Ident(Done);                     if not Done then Exit;
          while ActChar=',' do
            begin
              GetChar;
              Ident(Done);                 if not Done then Exit;
            end;
        end(*start_state_list*);
      begin(*start_state_prefix*)
        NSt := 0;
        if ActChar='<' then
          begin
            GetChar;
            StartStateList(Done);        if not Done then Exit;
            if ActChar='>' then
              begin
                Done := True;
                GetChar;
              end
            else
              Done := False
          end
        else
          Done := True
      end(*start_state_prefix*);
    procedure Caret( var Done : Boolean );
      begin(*caret*)
        Done := True;
        Cf   := ActChar='^';
        if ActChar='^' then GetChar;
      end(*caret*);

  procedure ScanChar ( var Done : Boolean; var C : Char );
    var
      OctVal : Byte;
      Count : Integer;
    begin
      Done := True;
      if ActChar='\' then
        begin
          GetChar;
          case ActChar of
            #0  : Done := False;
            'n' : begin
                    C := NL;
                    GetChar
                  end;
            'r' : begin
                    C := CR;
                    GetChar
                  end;
            't' : begin
                    C := Tab;
                    GetChar
                  end;
            'b' : begin
                    C := BS;
                    GetChar
                  end;
            'f' : begin
                    C := FF;
                    GetChar
                  end;
            '0'..'7' : begin
                         OctVal := Ord(ActChar)-Ord('0');
                         GetChar;
                         Count := 1;
                         while ('0'<=ActChar) and
                           (ActChar<='7') and
                           (Count<3) do
                           begin
                             Inc(Count);
                             OctVal := OctVal*8+Ord(ActChar)-Ord('0');
                             GetChar
                           end;
                         C := Chr(OctVal);
                       end
            else  begin
                    C := ActChar;
                    GetChar
                  end
          end
        end
      else
        begin
          C := ActChar;
          GetChar
        end
    end(*scan_char*);
  procedure ScanStr ( var Done : Boolean; var Str : String );
    var C : Char;
    begin
      Str := '';
      GetChar;
      while (ActChar<>#0) and (ActChar<>'"') do
        begin
          ScanChar(Done, C);        if not Done then Exit;
          Str := Str+C;
        end;
      if ActChar=#0 then
        Done := False
      else
        begin
          GetChar;
          Done := True;
        end
    end(*scan_str*);
  procedure ScanCclass( var Done : Boolean; var CC : TCClass );
    (* scan a character class *)
    var
      Caret : Boolean;
      C, C1,Cl : Char;
    begin
      CC := [];
      GetChar;
      if ActChar='^' then
        begin
          Caret := True;
          GetChar;
        end
      else
        Caret := False;
      while (ActChar<>#0) and (ActChar<>']') do
        begin
          ScanChar(Done, C);              if not Done then Exit;
          if ActChar='-' then
            begin
              GetChar;
              if (ActChar<>#0) and (ActChar<>']') then
                begin
                  ScanChar(Done, C1);     if not Done then Exit;
                  for Cl:=C to C1 do
                    CC:=CC+[Cl];
                   {cc := cc+[c..c1];}
                end
              else
                CC := CC+[C,'-'];
            end
          else
            CC := CC+[C];
        end;
      if ActChar=#0 then
        Done := False
      else
        begin
          GetChar;
          Done := True;
        end;
      if Caret then CC := [#1..#255]-CC;
    end(*scan_cclass*);
  procedure ScanNum( var Done : Boolean; var N : Integer );
    var Str : String;
    begin
      if ActChar in Digits then
        begin
          Str := ActChar;
          GetChar;
          while ActChar in Digits do
            begin
              Str := Str+ActChar;
              GetChar;
            end;
          Done := IsInt(Str, N);
        end
      else
        Done := False
    end(*scan_num*);

    procedure DoExpr ( var Done : Boolean; var R : PRegExpr );
      procedure Term ( var Done : Boolean; var R : PRegExpr );
        procedure Factor ( var Done : Boolean; var R : PRegExpr );
          var Str  : String;
              CC   : TCClass;
              C    : Char;
              N, M : Integer;
          begin(*factor*)
            case ActChar of
              '"' : begin
                      ScanStr(Done, Str);         if not Done then Exit;
                      R := StrExpr(NewStr(Str));
                    end;
              '[' : begin
                      ScanCclass(Done, CC);       if not Done then Exit;
                      R := CClassExpr(NewCClass(CC));
                    end;
              '.' : begin
                      GetChar;
                      R := CClassExpr(NewCClass([#1..#255]-[NL]));
                      Done := True;
                    end;
              '(' : begin
                      GetChar;
                      DoExpr(Done, R);               if not Done then Exit;
                      if ActChar=')' then
                        begin
                          GetChar;
                          Done := True;
                        end
                      else
                        Done := False
                    end;
              else  begin
                      ScanChar(Done, C);          if not Done then Exit;
                      R := CharExpr(C);
                    end;
            end;
            while Done and (ActChar in ['*','+','?','{']) do
              case ActChar of
                '*' : begin
                        GetChar;
                        R := StarExpr(R);
                      end;
                '+' : begin
                        GetChar;
                        R := PlusExpr(R);
                      end;
                '?' : begin
                        GetChar;
                        R := OptExpr(R);
                      end;
                '{' : begin
                        GetChar;
                        ScanNum(Done, M);         if not Done then Exit;
                        if ActChar=',' then
                          begin
                            GetChar;
                            ScanNum(Done, N);     if not Done then Exit;
                            R := MNExpr(R, M, N);
                          end
                        else
                          R := MNExpr(R, M, M);
                        if ActChar='}' then
                          begin
                            GetChar;
                            Done := True;
                          end
                        else
                          Done := False
                      end;
              end
          end(*factor*);
        const TermDelim : TCClass = [#0,' ',Tab,'$','|',')','/'];
        var R1 : PRegExpr;
        begin(*term*)
          if not (ActChar in TermDelim) then
            begin
              Factor(Done, R);             if not Done then Exit;
              while not (ActChar in TermDelim) do
                begin
                  Factor(Done, R1);        if not Done then Exit;
                  R := CatExpr(R, R1);
                end
            end
          else
            begin
              R := EpsExpr;
              Done := True;
            end
        end(*term*);
      var R1 : PRegExpr;
      begin(*expr*)
        Term(Done, R);                     if not Done then Exit;
        while ActChar='|' do
          begin
            GetChar;
            Term(Done, R1);                if not Done then Exit;
            R := AltExpr(R, R1);
          end
      end(*expr*);

    var R1, R2 : PRegExpr;

    begin(*rule*)
      StartStatePrefix(Done);            if not Done then Exit;
      Caret(Done);                         if not Done then Exit;
      DoExpr(Done, R1);                      if not Done then Exit;
      if ActChar='$' then
        begin
          R := CatExpr(CatExpr(R1,
                 MarkExpr(RuleNo, 1)),
                 CClassExpr(NewCClass([NL])));
          GetChar;
        end
      else if ActChar='/' then
        begin
          GetChar;
          DoExpr(Done, R2);                  if not Done then Exit;
          R := CatExpr(CatExpr(R1,
                 MarkExpr(RuleNo, 1)), R2);
        end
      else
        R := CatExpr(R1, MarkExpr(RuleNo, 1));
      R := CatExpr(R, MarkExpr(RuleNo, 0));
      Done := (ActChar=#0) or (ActChar=' ') or (ActChar=Tab);
    end(*rule*);

  var Done : Boolean;

  begin(*parse_rule*)
    InitScanner;
    Rule(Done);
    if Done then
      begin
        Expr := Copy(Line, 1, ActPos-1);
        Stmt := Copy(Line, ActPos, Length(Line));
      end
    else
      MarkError(SyntaxError, 0)
  end(*parse_rule*);

end(*LexRules*).
