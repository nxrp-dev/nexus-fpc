
/* YACC.Y: Yacc grammar for Yacc main program. 2-17-91, 4-30-91 AG
   To bootstrap Yacc, use Yacc iself to compile this grammar, then
   run tpc on the generated program.

   Note:

   This is not entirely the `official' syntax introduced by Johnson, but it
   should be compatible with UNIX Yacc (except for the differences specified
   in the program header, below), as described in the UNIX manual, including
   the language elements entitled as "old features supported but not
   encouraged."

   Bugs:

   - Processes $$'s, $i's, %} and } inside of comments in Turbo Pascal code
     (instead of ignoring them).

   Shift/reduce conflicts:

   This grammar will produce a number of shift/reduce conflicts caused by
   the error productions, since it does not specify unambigiously whether
   errors are to be handled in global structures (definitions and rules)
   or by enclosed syntactic constructs (e.g. symbols). Yacc will resolve
   these conflicts in favour of shift, which is o.k. (it means that
   errors will be caught in the innermost constructs with error handling,
   thus reducing the amount of skipped symbols in resynchronization).

   Error handling is done using the general method of Schreiner/Friedman
   (see Schreiner/Friedman, "Introduction to compiler construction with
   UNIX," 1985).

*/

%{
(*

  TP Yacc - Yet Another Compiler Compiler for Turbo Pascal

  Copyright (C) 1990-92  Albert Graef <ag@muwiinfa.geschichte.uni-mainz.de>
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


$Revision: 1.5 $
$Modtime: 96-08-01 11:24 $


Last changes:

  Version 3.0 as of April 91
  Version 3.0a as of May 92 (bug fixes in precedence and type information
    updates)

$History: YACC.PAS $
 * 
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.



------------------------- Synopsis ------------------------

   Synopsis   yacc [options] yacc-file[.y] [output-file[.pas]]

   Options

   -v  "Verbose:" Yacc generates a readable description of the generated
       parser, written to yacc-file with new extension .lst.

   -d  "Debug:" Yacc generates parser with debugging output.

   Description

   This is a reimplementation of the popular UNIX compiler generator
   Yacc for MS-DOS and Turbo Pascal.

   Differences from UNIX Yacc:

   - Produces output code for Turbo Pascal, rather than for C.

   - Does not support %union definitions. Instead, a value type is declared
     by specifying the type identifier *itself* as the tag of a %token
     or %type definition. Yacc will automatically generate an appropriate
     yylval variable of a variant record type (YYSType) which is capable of
     holding values of any of the types used in %token and %type.

     Type checking is *very* strict. If you use type definitions, then
     any symbol referred to in an action *must* have a type introduced
     in a type definition. Either the symbol must have been assigned a
     type in the definitions section, or the $<type-identifier> notation
     must be used. The syntax of the %type definition has been changed
     slightly to allow definitions of the form
       %type <type-identifier>
     (omitting the nonterminals) which may be used to declare types which
     are not assigned to any grammar symbol, but are used with the
     $<...> construct.

   - The parse tables constructed by this Yacc version are slightly greater
     than those constructed by UNIX Yacc, since a reduce action will only be
     chosen as the default action if it is the *only* action in the state.
     In difference, UNIX Yacc chooses a reduce action as the default action
     whenever it is the only *reduce* action of the state (even if there are
     other shift actions).

     This solves a bug in UNIX Yacc that makes the generated parser start
     error recovery too late with certain types of error productions (see
     also Schreiner/Friedman, "Introduction to compiler construction with
     UNIX," 1985). Also, errors will be caught sooner in most cases where
     standard Yacc would carry out an additional (default) reduction before
     detecting the error.

------------------------- Synopsis ------------------------

*)

{$X+}
{$I-}
program Yacc;

uses
{$IFDEF Debug}
{$IFDEF DPMI}
  { YaccChk, removed as obsolete,
    YaccChk source not available anymore PM }
{$ENDIF}
{$ENDIF}
  YaccLib, YaccBase, YaccMsgs, YaccSem, YaccTabl, YaccPars, SysUtils;

%}

/* Lexical part of the Yacc language: */

%token
  ID		/* identifiers: {letter}{letter_or_digit}* */
  CID		/* identifier which forms left side of rule, i.e. is
		   followed by a colon */
  Literal       /* single character literal */
  LitID         /* multiple character literal */
  Number	/* nonnegative integers: {digit}+ */
  PToken PLeft PRight PNonAssoc PType PStart PPrec
  		/* reserved words: PTOKEN=%token, etc. */
  PP		/* source sections separator %% */
  LCurl		/* curly braces: %{ and %} */
  RCurl
  ',' ':' ';' '|' '{' '}' '<' '>' '='
		/* literals */
  Illegal	/* illegal input character */

%start grammar

%%

/* Lexical entities, those that may give rise to syntax errors are augmented
   with error productions, and important symbols call yyerrok. */

id		: ID
c_id		: CID
literal         : Literal
litid           : LitID
number		: Number
ptoken		: PToken        { YYErrOK; }
pleft		: PLeft	        { YYErrOK; }
pright		: PRight        { YYErrOK; }
pnonassoc	: PNonAssoc	{ YYErrOK; }
ptype		: PType	        { YYErrOK; }
pstart		: PStart        { YYErrOK; }
pprec		: PPrec
pp		: PP	        { YYErrOK; }
lcurl		: LCurl
rcurl		: RCurl
		| error	        { Error(RCurlExpected); }
comma		: ','
colon		: ':'	        { YYErrOK; }
semicolon	: ';'	        { YYErrOK; }
bar		: '|'	        { YYErrOK; }
lbrace		: '{'
rbrace		: '}'
		| error	        { Error(RBraceExpected); }
langle		: '<'
rangle		: '>'
		| error         { Error(RAngleExpected); }
eq		: '='

/* Syntax and semantic routines: */

grammar		: defs pp
		  		{ SortTypes;
                                  Definitions;
                                  NextSection; }
		  rules
		  		{ NextSection;
                                  GenerateParser;
                                  NextSection; }
		  aux_procs
		;

aux_procs	: /* empty: aux_procs is optional */

		| pp { CopyRestOfFile; }

		;


defs		: /* empty */
		| defs def	{ YYErrOK; }
		| defs error	{ Error(ErrorInDef); }
		;

def		: pstart id
			 	{ StartNT := NTSym($2); }
		| pstart error
				{ Error(IdentExpected); }
		| lcurl { CopyCode; } rcurl

		| ptoken
				{ ActPrec := 0; }
		  tag token_list

		| pleft
				{ ActPrec := NewPrecLevel(Left); }
		  tag token_list

		| pright
				{ ActPrec := NewPrecLevel(Right); }
		  tag token_list

		| pnonassoc
				{ ActPrec := NewPrecLevel(NonAssoc); }
		  tag token_list

		| ptype tag nonterm_list

                | ptype tag

		;

tag		: /* empty: type tag is optional */
				{ ActType := 0; }
		| langle id rangle
				{ ActType := $2; AddType($2); }
		;

token_list	: token_num

		| token_list token_num
				{ YYErrOK; }
		| token_list comma token_num
				{ YYErrOK; }
		| error
				{ Error(IdentExpected); }
		| token_list error
				{ Error(ErrorInDef); }
		| token_list comma error
				{ Error(IdentExpected); }
		;

token_num	: literal
				{ if ActType<>0 then
                                    SymType^[$1] := ActType;
                                  if ActPrec<>0 then
                                    SymPrec^[$1] := ActPrec; }
               	| litid
				{ LitSym($1, 0);
                                  if ActType<>0 then
                                    SymType^[LitSym($1, 0)] := ActType;
                                  if ActPrec<>0 then
                                    SymPrec^[LitSym($1, 0)] := ActPrec; }
               	| id
				{ LitSym($1, 0);
                                  if ActType<>0 then
                                    SymType^[LitSym($1, 0)] := ActType;
                                  if ActPrec<>0 then
                                    SymPrec^[LitSym($1, 0)] := ActPrec; }
               	| litid number
				{ LitSym($1, 0);
                                  if ActType<>0 then
                                    SymType^[LitSym($1, $2)] := ActType;
                                  if ActPrec<>0 then
                                    SymPrec^[LitSym($1, 0)]  := ActPrec; }
               	| id number
				{ LitSym($1, 0);
                                  if ActType<>0 then
                                    SymType^[LitSym($1, $2)] := ActType;
                                  if ActPrec<>0 then
                                    SymPrec^[LitSym($1, 0)]  := ActPrec; }
		;

nonterm_list	: nonterm
		| nonterm_list nonterm
				{ YYErrOK; }
		| nonterm_list comma nonterm
				{ YYErrOK; }
		| error
				{ Error(IdentExpected); }
		| nonterm_list error
				{ Error(ErrorInDef); }
		| nonterm_list comma error
				{ Error(IdentExpected); }
		;

nonterm		: id
				{ if ActType<>0 then
                                    SymType^[NTSym($1)] := ActType; }
		;


rules		: 		{ NextSection; }
		  rule1

		| lcurl { CopyCode; } rcurl
				{ NextSection; }
		  rule1
					/* rules section may be prefixed
					   with `local' Turbo Pascal
					   declarations */
		| rules rule
				{ YYErrOK; }
		| error
				{ Error(ErrorInRule); }
		| rules error
				{ Error(ErrorInRule); }
		;

rule1		: c_id
				{ StartRule(NTSym($1)); }
		  colon
		  		{ StartBody; }
		  body prec
				{ EndBody; }
		;

rule		: rule1

		| bar
				{ StartBody; }
		  body prec
				{ EndBody; }
		;

body		: /* empty */

		| body literal
				{ AddSymbol($2); YYErrOK; }
		| body litid
				{ AddSymbol(Sym($2)); YYErrOK; }
		| body id
				{ AddSymbol(Sym($2)); YYErrOK; }
                | body action
				{ AddAction; YYErrOK; }
		| body error
				{ Error(ErrorInRule); }
		;

action		: lbrace { CopyAction; } rbrace

		| eq { CopySingleAction; }
                		/* old language feature; code must be
				   single statement ending with `;' */
		;

prec		: /* empty */

		| pprec literal
				{ AddRulePrec($2); }
		  opt_action

		| pprec litid
				{ AddRulePrec(LitSym($2, 0)); }
		  opt_action

		| pprec id
				{ AddRulePrec(LitSym($2, 0)); }
		  opt_action

		| prec semicolon

		;

opt_action	: /* empty */

		| action
				{ AddAction; }
		;


%%

(* Lexical analyzer (implemented in Turbo Pascal for maximum efficiency): *)

function yylex : Integer;
  function EndOfInput : Boolean;
    begin
      EndOfInput := (CNo>Length(Line)) and EOF(YYIn)
    end(*end_of_input*);
  procedure Scan;
    (* scan for nonempty character, skip comments *)
    procedure ScanComment;
      var P : Integer;
      begin
        P := POS('*/', Copy(Line, CNo, Length(Line)));
        if P>0 then
          CNo := CNo+Succ(P)
        else
          begin
            while (P=0) and not EOF(YYIn) do
              begin
                ReadLn(YYIn, Line);
                Inc(LNo);
                P := POS('*/', Line)
              end;
            if P=0 then
              begin
                CNo := Succ(Length(Line));
                Error(OpenCommentAtEOF);
              end
            else
              CNo := Succ(Succ(P))
          end
      end(*scan_comment*);
    begin
      while not EndOfInput do
        if CNo<=Length(Line) then
          case Line[CNo] of
            ' ', Tab : Inc(CNo);
            '/' :
              if (CNo<Length(Line)) and (Line[Succ(CNo)]='*') then
                begin
                  Inc(CNo, 2);
                  ScanComment
                end
              else
                Exit
            else
              Exit
          end
        else
          begin
            ReadLn(YYIn, Line);
            Inc(LNo); CNo := 1;
          end
    end(*scan*);
  function ScanIdent : Integer;
    (* scan an identifier *)
    var
      IDStr : String;
    begin
      IDStr := Line[CNo];
      Inc(CNo);
      while (CNo<=Length(Line)) and (
            ('A'<=UpCase(Line[CNo])) and (UpCase(Line[CNo])<='Z') or
            ('0'<=Line[CNo]) and (Line[CNo]<='9') or
            (Line[CNo]='_') or
            (Line[CNo]='.') ) do
	begin
	  IDStr := IDStr+Line[CNo];
	  Inc(CNo)
	end;
      yylval := GetKey(IDStr);
      Scan;
      if not EndOfInput and (Line[CNo]=':') then
        ScanIdent := CID
      else
        ScanIdent := ID
    end(*scan_ident*);
  function ScanLiteral: Integer;
    (* scan a literal, i.e. string *)
    var
      IDStr : String;
      OctVal : Byte;
    begin
      IDStr := Line[CNo];
      Inc(CNo);
      while (CNo<=Length(Line)) and (Line[CNo]<>IDStr[1]) do
        if Line[CNo]='\' then
          if CNo<Length(Line) then
            begin
              Inc(CNo);
              case Line[CNo] of
                'n' :
                  begin
                    IDStr := IDStr+NL;
                    Inc(CNo)
                  end;
                'r' :
                  begin
                    IDStr := IDStr+CR;
                    Inc(CNo)
                  end;
                't' :
                  begin
                    IDStr := IDStr+Tab;
                    Inc(CNo)
                  end;
                'b' :
                  begin
                    IDStr := IDStr+BS;
                    Inc(CNo)
                  end;
                'f' :
                  begin
                    IDStr := IDStr+FF;
                    Inc(CNo)
                  end;
                '0'..'7' :
                  begin
                    OctVal := Ord(Line[CNo])-Ord('0');
                    Inc(CNo);
                    while (CNo<=Length(Line)) and
                          ('0'<=Line[CNo]) and
                          (Line[CNo]<='7') do
                      begin
                        OctVal := OctVal*8+Ord(Line[CNo])-Ord('0');
                        Inc(CNo)
                      end;
                    IDStr := IDStr+Chr(OctVal)
                  end
                else
                  begin
                    IDStr := IDStr+Line[CNo];
                    Inc(CNo)
                  end
              end
            end
          else
            Inc(CNo)
        else
          begin
            IDStr := IDStr+Line[CNo];
            Inc(CNo)
          end;
      if CNo>Length(Line) then
        Error(MissingStringTerminator)
      else
        Inc(CNo);
      if Length(IDStr)=2 then
        begin
          yylval := Ord(IDStr[2]);
          ScanLiteral := Literal;
        end
      else if Length(IDStr)>1 then
        begin
          yylval := GetKey(''''+Copy(IDStr, 2, Pred(Length(IDStr)))+'''');
          ScanLiteral := LitID;
        end
      else
        ScanLiteral := Illegal;
    end(*scan_literal*);
  function ScanNum : Integer;
    (* scan an unsigned integer *)
    var
      NumStr : String;
      Code : Integer;
    begin
      NumStr := Line[CNo];
      Inc(CNo);
      while (CNo<=Length(Line)) and
            ('0'<=Line[CNo]) and (Line[CNo]<='9') do
        begin
          NumStr := NumStr+Line[CNo];
          Inc(CNo)
        end;
      Val(NumStr, yylval, Code);
      if Code=0 then
        ScanNum := Number
      else
        ScanNum := Illegal;
    end(*scan_num*);
  function ScanKeyword : Integer;
    (* scan %xy *)
    function Lookup(Key : String; var Tok : Integer) : Boolean;
      (* table of Yacc keywords (unstropped): *)
      const
        NoOfEntries = 11;
        MaxEntryLength = 8;
        Keys : array [1..NoOfEntries] of String[MaxEntryLength] = (
          '0', '2', 'binary', 'left', 'nonassoc', 'prec', 'right',
          'start', 'term', 'token', 'type');
        Toks : array [1..NoOfEntries] of Integer = (
          PToken, PNonAssoc, PNonAssoc, PLeft, PNonAssoc, PPrec, PRight,
          PStart, PToken, PToken, PType);
      var M, N, K : Integer;
      begin
        (* binary search: *)
        M := 1; N := NoOfEntries;
        Lookup := True;
        while M<=N do
          begin
            K := M+(N-M) div 2;
            if Key=Keys[K] then
              begin
                Tok := Toks[K];
                Exit
              end
            else if Key>Keys[K] then
              M := K+1
            else
              N := K-1
          end;
        Lookup := False
      end(*lookup*);
    var
      KeywStr : String;
      Tok : Integer;
    begin
      Inc(CNo);
      if CNo<=Length(Line) then
        case Line[CNo] of
          '<' :
            begin
              ScanKeyword := PLeft;
              Inc(CNo)
            end;
          '>' :
            begin
              ScanKeyword := PRight;
              Inc(CNo)
            end;
          '=' :
            begin
              ScanKeyword := PPrec;
              Inc(CNo)
            end;
          '%', '\' :
            begin
              ScanKeyword := PP;
              Inc(CNo)
            end;
          '{' :
            begin
              ScanKeyword := LCurl;
              Inc(CNo)
            end;
          '}' :
            begin
              ScanKeyword := RCurl;
              Inc(CNo)
            end;
          'A'..'Z', 'a'..'z', '0'..'9' :
            begin
              KeywStr := Line[CNo];
              Inc(CNo);
              while (CNo<=Length(Line)) and (
                    ('A'<=UpCase(Line[CNo])) and (UpCase(Line[CNo])<='Z') or
                    ('0'<=Line[CNo]) and (Line[CNo]<='Z') ) do
                begin
                  KeywStr := KeywStr+Line[CNo];
                  Inc(CNo)
                end;
              if Lookup(KeywStr, Tok) then
                ScanKeyword := Tok
              else
                ScanKeyword := Illegal
            end;
          else ScanKeyword := Illegal
        end
      else
        ScanKeyword := Illegal;
    end(*scan_keyword*);
  function ScanChar : Integer;
    (* scan any single character *)
    begin
      ScanChar := Ord(Line[CNo]);
      Inc(CNo)
    end(*scan_char*);
  var LNo0, CNo0 : Integer;
  begin
    TokLeng := 0;
    Scan;
    LNo0 := LNo; CNo0 := CNo;
    if EndOfInput then
      yylex := 0
    else
      case Line[CNo] of
        'A'..'Z', 'a'..'z', '_' : yylex := ScanIdent;
	'''', '"' : yylex := ScanLiteral;
	'0'..'9' : yylex := ScanNum;
	'%', '\' : yylex := ScanKeyword;
        '=' :
          if (CNo<Length(Line)) and (Line[Succ(CNo)]='{') then
            begin
              Inc(CNo);
              yylex := ScanChar
            end
          else
            yylex := ScanChar;
	else yylex := ScanChar;
      end;
    if LNo=LNo0 then
      TokLeng := CNo-CNo0
  end(*yylex*);

(* Main program: *)

var I : Integer;

begin
{$ifdef Unix}
  CodFilePath1:=Path(ParamStr(0));
  if (CodFilePath1<>'') then
    CodFilePath1:=CodFilePath1+'../lib/fpc/lexyacc/'
  else
    CodFilePath1:='/usr/local/lib/fpc/lexyacc/';
  CodFilePath2:='/usr/lib/fpc/lexyacc/';
{$else}
  CodFilePath1:=Path(ParamStr(0));
  CodFilePath2:='';
{$endif}

  (* sign-on: *)

  WriteLn(SignOn);

  (* parse command line: *)

  if ParamCount=0 then
    begin
      WriteLn(Usage);
      WriteLn(Options);
      Halt(0);
    end;

  YFileName := '';
  PasFileName := '';

  for I := 1 to ParamCount do
    if Copy(ParamStr(I), 1, 1)='-' then
      if Upper(ParamStr(I))='-V' then
        Verbose := True
      else if Upper(ParamStr(I))='-D' then
        Debug := True
      else
        begin
          WriteLn(InvalidOption, ParamStr(I));
          Halt(1);
        end
    else if YFileName='' then
      YFileName := AddExt(ParamStr(I), 'y')
    else if PasFileName='' then
      PasFileName := AddExt(ParamStr(I), 'pas')
    else
      begin
        WriteLn(IllegalNoArgs);
        Halt(1);
      end;

  if YFileName='' then
    begin
      WriteLn(IllegalNoArgs);
      Halt(1);
    end;

  if PasFileName='' then PasFileName := Root(YFileName)+'.pas';
  LstFileName := Root(YFileName)+'.lst';

  (* open files: *)

  Assign(YYIn, YFileName);
  Assign(YYOut, PasFileName);
  Assign(YYLst, LstFileName);

  Reset(YYIn);    if IOResult<>0 then Fatal(CannotOpenFile+YFileName);
  Rewrite(YYOut); if IOResult<>0 then Fatal(CannotOpenFile+PasFileName);
  Rewrite(YYLst); if IOResult<>0 then Fatal(CannotOpenFile+LstFileName);

  (* search code template *)
  CodFileName := 'yyparse.cod';
  Assign(YYCod, CodFileName);
  Reset(YYCod);
  if IOResult<>0 then
    begin
      CodFileName := IncludeTrailingPathDelimiter(GetEnvironmentVariable('FPCDIR'))+'lexyacc'+DirectorySeparator+'yyparse.cod';
      Assign(YYCod, CodFileName);
      Reset(YYCod);
      if IOResult<>0 then
        begin
          CodFileName := CodFilePath1+'yyparse.cod';
          Assign(YYCod, CodFileName);
          Reset(YYCod);
          if (CodFilePath2<>'') and (IOResult<>0) then 
            begin
              CodFileName := CodFilePath2+'yyparse.cod';
              Assign(YYCod, CodFileName);
              Reset(YYCod);
              if IOResult<>0 then 
                Fatal(CannotOpenFile+CodFileName);
            end;
        end;
    end;

  (* parse source grammar: *)

  Write('parse ... ');

  LNo := 0; CNo := 1; Line := '';

  NextSection;
  if Debug then WriteLn(YYOut, '{$define yydebug}');

  if yyparse=0 then
    { done }
  else if YYChar=0 then
    Error(UnexpectedEOF)
  else
    Error(SyntaxError);

  if Errors=0 then WriteLn('DONE');

  (* close files: *)

  Close(YYIn); Close(YYOut); Close(YYLst); Close(YYCod);

  (* print statistics: *)

  if Errors>0 then
    WriteLn( LNo, ' lines, ',
             Errors, ' errors found.' )
  else
    begin
      WriteLn( LNo, ' lines, ',
               NRules-1, '/', MaxRules-1, ' rules, ',
               NStates, '/', MaxStates, ' s, ',
               NItems, '/', MaxItems, ' i, ',
               NTrans, '/', MaxTrans, ' t, ',
               NRedns, '/', MaxRedns, ' r.');
      if ShiftReduce>0 then
        WriteLn(ShiftReduce, ' shift/reduce conflicts.');
      if ReduceReduce>0 then
        WriteLn(ReduceReduce, ' reduce/reduce conflicts.');
      if NeverReduced>0 then
        WriteLn(NeverReduced, ' rules never reduced.');
    end;

  if Warnings>0 then WriteLn(Warnings, ' warnings.');

  (* terminate: *)

  if Errors>0 then
    begin
      Erase(YYOut);
      if IOResult<>0 then ;
    end;

  if GetFileSize(LstFileName)=0 then
    Erase(YYLst)
  else
    WriteLn('(see ', LstFileName, ' for more information)');

  Halt(Errors);

end(*Yacc*).
