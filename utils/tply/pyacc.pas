
(* Yacc parser template (TP Yacc V3.0), V1.2 6-17-91 AG *)

(* global definitions: *)

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
{$ENDIF}
  YaccLib, YaccBase, YaccMsgs, YaccSem, YaccTabl, YaccPars, SysUtils;

const ID = 257;
const CID = 258;
const Literal = 259;
const LitID = 260;
const Number = 261;
const PToken = 262;
const PLeft = 263;
const PRight = 264;
const PNonAssoc = 265;
const PType = 266;
const PStart = 267;
const PPrec = 268;
const PP = 269;
const LCurl = 270;
const RCurl = 271;
const Illegal = 272;

var yylval : YYSType;

function yylex : Integer; forward;

function yyparse : Integer;

var YYState, YYSP, YYN : Integer;
    YYS : array [1..YYMaxDepth] of Integer;
    YYV : array [1..YYMaxDepth] of YYSType;
    yyval : YYSType;

procedure YYAction ( YYRuleNo : Integer );
  (* local definitions: *)
begin
  (* actions: *)
  case YYRuleNo of
   1 : begin
         yyval := YYV[YYSP-0];
       end;
   2 : begin
         yyval := YYV[YYSP-0];
       end;
   3 : begin
         yyval := YYV[YYSP-0];
       end;
   4 : begin
         yyval := YYV[YYSP-0];
       end;
   5 : begin
         yyval := YYV[YYSP-0];
       end;
   6 : begin
         YYErrOK;
       end;
   7 : begin
         YYErrOK;
       end;
   8 : begin
         YYErrOK;
       end;
   9 : begin
         YYErrOK;
       end;
  10 : begin
         YYErrOK;
       end;
  11 : begin
         YYErrOK;
       end;
  12 : begin
         yyval := YYV[YYSP-0];
       end;
  13 : begin
         YYErrOK;
       end;
  14 : begin
         yyval := YYV[YYSP-0];
       end;
  15 : begin
         yyval := YYV[YYSP-0];
       end;
  16 : begin
         Error(RCurlExpected);
       end;
  17 : begin
         yyval := YYV[YYSP-0];
       end;
  18 : begin
         YYErrOK;
       end;
  19 : begin
         YYErrOK;
       end;
  20 : begin
         YYErrOK;
       end;
  21 : begin
         yyval := YYV[YYSP-0];
       end;
  22 : begin
         yyval := YYV[YYSP-0];
       end;
  23 : begin
         Error(RBraceExpected);
       end;
  24 : begin
         yyval := YYV[YYSP-0];
       end;
  25 : begin
         yyval := YYV[YYSP-0];
       end;
  26 : begin
         Error(RAngleExpected);
       end;
  27 : begin
         yyval := YYV[YYSP-0];
       end;
  28 : begin
         SortTypes;
         Definitions;
         NextSection;
       end;
  29 : begin
         NextSection;
         GenerateParser;
         NextSection;
       end;
  30 : begin
         yyval := YYV[YYSP-5];
       end;
  31 : begin
       end;
  32 : begin
         CopyRestOfFile;
       end;
  33 : begin
       end;
  34 : begin
         YYErrOK;
       end;
  35 : begin
         Error(ErrorInDef);
       end;
  36 : begin
         StartNT := NTSym(YYV[YYSP-0]);
       end;
  37 : begin
         Error(IdentExpected);
       end;
  38 : begin
         CopyCode;
       end;
  39 : begin
         yyval := YYV[YYSP-2];
       end;
  40 : begin
         ActPrec := 0;
       end;
  41 : begin
         yyval := YYV[YYSP-3];
       end;
  42 : begin
         ActPrec := NewPrecLevel(Left);
       end;
  43 : begin
         yyval := YYV[YYSP-3];
       end;
  44 : begin
         ActPrec := NewPrecLevel(Right);
       end;
  45 : begin
         yyval := YYV[YYSP-3];
       end;
  46 : begin
         ActPrec := NewPrecLevel(NonAssoc);
       end;
  47 : begin
         yyval := YYV[YYSP-3];
       end;
  48 : begin
         yyval := YYV[YYSP-2];
       end;
  49 : begin
         yyval := YYV[YYSP-1];
       end;
  50 : begin
         ActType := 0;
       end;
  51 : begin
         ActType := YYV[YYSP-1]; AddType(YYV[YYSP-1]);
       end;
  52 : begin
         yyval := YYV[YYSP-0];
       end;
  53 : begin
         YYErrOK;
       end;
  54 : begin
         YYErrOK;
       end;
  55 : begin
         Error(IdentExpected);
       end;
  56 : begin
         Error(ErrorInDef);
       end;
  57 : begin
         Error(IdentExpected);
       end;
  58 : begin
         if ActType<>0 then
         SymType^[YYV[YYSP-0]] := ActType;
         if ActPrec<>0 then
         SymPrec^[YYV[YYSP-0]] := ActPrec;
       end;
  59 : begin
         LitSym(YYV[YYSP-0], 0);
         if ActType<>0 then
         SymType^[LitSym(YYV[YYSP-0], 0)] := ActType;
         if ActPrec<>0 then
         SymPrec^[LitSym(YYV[YYSP-0], 0)] := ActPrec;
       end;
  60 : begin
         LitSym(YYV[YYSP-0], 0);
         if ActType<>0 then
         SymType^[LitSym(YYV[YYSP-0], 0)] := ActType;
         if ActPrec<>0 then
         SymPrec^[LitSym(YYV[YYSP-0], 0)] := ActPrec;
       end;
  61 : begin
         LitSym(YYV[YYSP-1], 0);
         if ActType<>0 then
         SymType^[LitSym(YYV[YYSP-1], YYV[YYSP-0])] := ActType;
         if ActPrec<>0 then
         SymPrec^[LitSym(YYV[YYSP-1], 0)]  := ActPrec;
       end;
  62 : begin
         LitSym(YYV[YYSP-1], 0);
         if ActType<>0 then
         SymType^[LitSym(YYV[YYSP-1], YYV[YYSP-0])] := ActType;
         if ActPrec<>0 then
         SymPrec^[LitSym(YYV[YYSP-1], 0)]  := ActPrec;
       end;
  63 : begin
         yyval := YYV[YYSP-0];
       end;
  64 : begin
         YYErrOK;
       end;
  65 : begin
         YYErrOK;
       end;
  66 : begin
         Error(IdentExpected);
       end;
  67 : begin
         Error(ErrorInDef);
       end;
  68 : begin
         Error(IdentExpected);
       end;
  69 : begin
         if ActType<>0 then
         SymType^[NTSym(YYV[YYSP-0])] := ActType;
       end;
  70 : begin
         NextSection;
       end;
  71 : begin
         yyval := YYV[YYSP-1];
       end;
  72 : begin
         CopyCode;
       end;
  73 : begin
         NextSection;
       end;
  74 : begin
         yyval := YYV[YYSP-4];
       end;
  75 : begin
         YYErrOK;
       end;
  76 : begin
         Error(ErrorInRule);
       end;
  77 : begin
         Error(ErrorInRule);
       end;
  78 : begin
         StartRule(NTSym(YYV[YYSP-0]));
       end;
  79 : begin
         StartBody;
       end;
  80 : begin
         EndBody;
       end;
  81 : begin
         yyval := YYV[YYSP-0];
       end;
  82 : begin
         StartBody;
       end;
  83 : begin
         EndBody;
       end;
  84 : begin
       end;
  85 : begin
         AddSymbol(YYV[YYSP-0]); YYErrOK;
       end;
  86 : begin
         AddSymbol(Sym(YYV[YYSP-0])); YYErrOK;
       end;
  87 : begin
         AddSymbol(Sym(YYV[YYSP-0])); YYErrOK;
       end;
  88 : begin
         AddAction; YYErrOK;
       end;
  89 : begin
         Error(ErrorInRule);
       end;
  90 : begin
         CopyAction;
       end;
  91 : begin
         yyval := YYV[YYSP-2];
       end;
  92 : begin
         CopySingleAction;
       end;
  93 : begin
       end;
  94 : begin
         AddRulePrec(YYV[YYSP-0]);
       end;
  95 : begin
         yyval := YYV[YYSP-3];
       end;
  96 : begin
         AddRulePrec(LitSym(YYV[YYSP-0], 0));
       end;
  97 : begin
         yyval := YYV[YYSP-3];
       end;
  98 : begin
         AddRulePrec(LitSym(YYV[YYSP-0], 0));
       end;
  99 : begin
         yyval := YYV[YYSP-3];
       end;
 100 : begin
         yyval := YYV[YYSP-1];
       end;
 101 : begin
       end;
 102 : begin
         AddAction;
       end;
  end;
end(*yyaction*);

(* parse table: *)

type TYYARec = record
                Sym, Act : Integer;
              end;
     TYYRRec = record
                Len, Sym : Integer;
              end;

const

YYNActs   = 251;
YYNGotos  = 146;
YYNStates = 128;
YYNRules  = 102;

YYA : array [1..YYNActs] of TYYARec = (
{ 0: }
{ 1: }
  ( Sym: 256; Act: 12 ),
  ( Sym: 262; Act: 13 ),
  ( Sym: 263; Act: 14 ),
  ( Sym: 264; Act: 15 ),
  ( Sym: 265; Act: 16 ),
  ( Sym: 266; Act: 17 ),
  ( Sym: 267; Act: 18 ),
  ( Sym: 269; Act: 19 ),
  ( Sym: 270; Act: 20 ),
{ 2: }
  ( Sym: 0; Act: 0 ),
{ 3: }
{ 4: }
{ 5: }
{ 6: }
  ( Sym: 256; Act: 24 ),
  ( Sym: 257; Act: 25 ),
{ 7: }
  ( Sym: 60; Act: 28 ),
  ( Sym: 256; Act: -50 ),
  ( Sym: 257; Act: -50 ),
  ( Sym: 262; Act: -50 ),
  ( Sym: 263; Act: -50 ),
  ( Sym: 264; Act: -50 ),
  ( Sym: 265; Act: -50 ),
  ( Sym: 266; Act: -50 ),
  ( Sym: 267; Act: -50 ),
  ( Sym: 269; Act: -50 ),
  ( Sym: 270; Act: -50 ),
{ 8: }
{ 9: }
{ 10: }
{ 11: }
{ 12: }
{ 13: }
{ 14: }
{ 15: }
{ 16: }
{ 17: }
{ 18: }
{ 19: }
{ 20: }
{ 21: }
  ( Sym: 256; Act: 34 ),
  ( Sym: 271; Act: 35 ),
{ 22: }
  ( Sym: 256; Act: 39 ),
  ( Sym: 270; Act: 20 ),
  ( Sym: 258; Act: -70 ),
{ 23: }
{ 24: }
{ 25: }
{ 26: }
  ( Sym: 256; Act: 43 ),
  ( Sym: 257; Act: 25 ),
  ( Sym: 262; Act: -49 ),
  ( Sym: 263; Act: -49 ),
  ( Sym: 264; Act: -49 ),
  ( Sym: 265; Act: -49 ),
  ( Sym: 266; Act: -49 ),
  ( Sym: 267; Act: -49 ),
  ( Sym: 269; Act: -49 ),
  ( Sym: 270; Act: -49 ),
{ 27: }
  ( Sym: 257; Act: 25 ),
{ 28: }
{ 29: }
  ( Sym: 60; Act: 28 ),
  ( Sym: 256; Act: -50 ),
  ( Sym: 257; Act: -50 ),
  ( Sym: 259; Act: -50 ),
  ( Sym: 260; Act: -50 ),
{ 30: }
  ( Sym: 60; Act: 28 ),
  ( Sym: 256; Act: -50 ),
  ( Sym: 257; Act: -50 ),
  ( Sym: 259; Act: -50 ),
  ( Sym: 260; Act: -50 ),
{ 31: }
  ( Sym: 60; Act: 28 ),
  ( Sym: 256; Act: -50 ),
  ( Sym: 257; Act: -50 ),
  ( Sym: 259; Act: -50 ),
  ( Sym: 260; Act: -50 ),
{ 32: }
  ( Sym: 60; Act: 28 ),
  ( Sym: 256; Act: -50 ),
  ( Sym: 257; Act: -50 ),
  ( Sym: 259; Act: -50 ),
  ( Sym: 260; Act: -50 ),
{ 33: }
{ 34: }
{ 35: }
{ 36: }
  ( Sym: 258; Act: 51 ),
{ 37: }
  ( Sym: 124; Act: 56 ),
  ( Sym: 256; Act: 57 ),
  ( Sym: 258; Act: 51 ),
  ( Sym: 0; Act: -29 ),
  ( Sym: 269; Act: -29 ),
{ 38: }
{ 39: }
{ 40: }
{ 41: }
  ( Sym: 44; Act: 61 ),
  ( Sym: 256; Act: 62 ),
  ( Sym: 257; Act: 25 ),
  ( Sym: 262; Act: -48 ),
  ( Sym: 263; Act: -48 ),
  ( Sym: 264; Act: -48 ),
  ( Sym: 265; Act: -48 ),
  ( Sym: 266; Act: -48 ),
  ( Sym: 267; Act: -48 ),
  ( Sym: 269; Act: -48 ),
  ( Sym: 270; Act: -48 ),
{ 42: }
{ 43: }
{ 44: }
  ( Sym: 62; Act: 64 ),
  ( Sym: 256; Act: 65 ),
{ 45: }
  ( Sym: 256; Act: 71 ),
  ( Sym: 257; Act: 25 ),
  ( Sym: 259; Act: 72 ),
  ( Sym: 260; Act: 73 ),
{ 46: }
  ( Sym: 256; Act: 71 ),
  ( Sym: 257; Act: 25 ),
  ( Sym: 259; Act: 72 ),
  ( Sym: 260; Act: 73 ),
{ 47: }
  ( Sym: 256; Act: 71 ),
  ( Sym: 257; Act: 25 ),
  ( Sym: 259; Act: 72 ),
  ( Sym: 260; Act: 73 ),
{ 48: }
  ( Sym: 256; Act: 71 ),
  ( Sym: 257; Act: 25 ),
  ( Sym: 259; Act: 72 ),
  ( Sym: 260; Act: 73 ),
{ 49: }
{ 50: }
{ 51: }
{ 52: }
{ 53: }
{ 54: }
  ( Sym: 269; Act: 19 ),
  ( Sym: 0; Act: -31 ),
{ 55: }
{ 56: }
{ 57: }
{ 58: }
  ( Sym: 256; Act: 34 ),
  ( Sym: 271; Act: 35 ),
{ 59: }
{ 60: }
  ( Sym: 256; Act: 83 ),
  ( Sym: 257; Act: 25 ),
{ 61: }
{ 62: }
{ 63: }
{ 64: }
{ 65: }
{ 66: }
{ 67: }
  ( Sym: 44; Act: 61 ),
  ( Sym: 256; Act: 86 ),
  ( Sym: 257; Act: 25 ),
  ( Sym: 259; Act: 72 ),
  ( Sym: 260; Act: 73 ),
  ( Sym: 262; Act: -47 ),
  ( Sym: 263; Act: -47 ),
  ( Sym: 264; Act: -47 ),
  ( Sym: 265; Act: -47 ),
  ( Sym: 266; Act: -47 ),
  ( Sym: 267; Act: -47 ),
  ( Sym: 269; Act: -47 ),
  ( Sym: 270; Act: -47 ),
{ 68: }
  ( Sym: 261; Act: 88 ),
  ( Sym: 44; Act: -59 ),
  ( Sym: 256; Act: -59 ),
  ( Sym: 257; Act: -59 ),
  ( Sym: 259; Act: -59 ),
  ( Sym: 260; Act: -59 ),
  ( Sym: 262; Act: -59 ),
  ( Sym: 263; Act: -59 ),
  ( Sym: 264; Act: -59 ),
  ( Sym: 265; Act: -59 ),
  ( Sym: 266; Act: -59 ),
  ( Sym: 267; Act: -59 ),
  ( Sym: 269; Act: -59 ),
  ( Sym: 270; Act: -59 ),
{ 69: }
{ 70: }
  ( Sym: 261; Act: 88 ),
  ( Sym: 44; Act: -60 ),
  ( Sym: 256; Act: -60 ),
  ( Sym: 257; Act: -60 ),
  ( Sym: 259; Act: -60 ),
  ( Sym: 260; Act: -60 ),
  ( Sym: 262; Act: -60 ),
  ( Sym: 263; Act: -60 ),
  ( Sym: 264; Act: -60 ),
  ( Sym: 265; Act: -60 ),
  ( Sym: 266; Act: -60 ),
  ( Sym: 267; Act: -60 ),
  ( Sym: 269; Act: -60 ),
  ( Sym: 270; Act: -60 ),
{ 71: }
{ 72: }
{ 73: }
{ 74: }
  ( Sym: 44; Act: 61 ),
  ( Sym: 256; Act: 86 ),
  ( Sym: 257; Act: 25 ),
  ( Sym: 259; Act: 72 ),
  ( Sym: 260; Act: 73 ),
  ( Sym: 262; Act: -45 ),
  ( Sym: 263; Act: -45 ),
  ( Sym: 264; Act: -45 ),
  ( Sym: 265; Act: -45 ),
  ( Sym: 266; Act: -45 ),
  ( Sym: 267; Act: -45 ),
  ( Sym: 269; Act: -45 ),
  ( Sym: 270; Act: -45 ),
{ 75: }
  ( Sym: 44; Act: 61 ),
  ( Sym: 256; Act: 86 ),
  ( Sym: 257; Act: 25 ),
  ( Sym: 259; Act: 72 ),
  ( Sym: 260; Act: 73 ),
  ( Sym: 262; Act: -43 ),
  ( Sym: 263; Act: -43 ),
  ( Sym: 264; Act: -43 ),
  ( Sym: 265; Act: -43 ),
  ( Sym: 266; Act: -43 ),
  ( Sym: 267; Act: -43 ),
  ( Sym: 269; Act: -43 ),
  ( Sym: 270; Act: -43 ),
{ 76: }
  ( Sym: 44; Act: 61 ),
  ( Sym: 256; Act: 86 ),
  ( Sym: 257; Act: 25 ),
  ( Sym: 259; Act: 72 ),
  ( Sym: 260; Act: 73 ),
  ( Sym: 262; Act: -41 ),
  ( Sym: 263; Act: -41 ),
  ( Sym: 264; Act: -41 ),
  ( Sym: 265; Act: -41 ),
  ( Sym: 266; Act: -41 ),
  ( Sym: 267; Act: -41 ),
  ( Sym: 269; Act: -41 ),
  ( Sym: 270; Act: -41 ),
{ 77: }
  ( Sym: 58; Act: 91 ),
{ 78: }
{ 79: }
{ 80: }
{ 81: }
{ 82: }
{ 83: }
{ 84: }
{ 85: }
  ( Sym: 256; Act: 95 ),
  ( Sym: 257; Act: 25 ),
  ( Sym: 259; Act: 72 ),
  ( Sym: 260; Act: 73 ),
{ 86: }
{ 87: }
{ 88: }
{ 89: }
{ 90: }
{ 91: }
{ 92: }
  ( Sym: 61; Act: 105 ),
  ( Sym: 123; Act: 106 ),
  ( Sym: 256; Act: 107 ),
  ( Sym: 257; Act: 25 ),
  ( Sym: 259; Act: 72 ),
  ( Sym: 260; Act: 73 ),
  ( Sym: 268; Act: 108 ),
  ( Sym: 0; Act: -93 ),
  ( Sym: 59; Act: -93 ),
  ( Sym: 124; Act: -93 ),
  ( Sym: 258; Act: -93 ),
  ( Sym: 269; Act: -93 ),
{ 93: }
  ( Sym: 258; Act: 51 ),
{ 94: }
{ 95: }
{ 96: }
{ 97: }
{ 98: }
  ( Sym: 59; Act: 112 ),
  ( Sym: 0; Act: -83 ),
  ( Sym: 124; Act: -83 ),
  ( Sym: 256; Act: -83 ),
  ( Sym: 258; Act: -83 ),
  ( Sym: 269; Act: -83 ),
{ 99: }
{ 100: }
{ 101: }
  ( Sym: 257; Act: 25 ),
  ( Sym: 259; Act: 72 ),
  ( Sym: 260; Act: 73 ),
{ 102: }
{ 103: }
{ 104: }
{ 105: }
{ 106: }
{ 107: }
{ 108: }
{ 109: }
{ 110: }
  ( Sym: 61; Act: 105 ),
  ( Sym: 123; Act: 106 ),
  ( Sym: 256; Act: 107 ),
  ( Sym: 257; Act: 25 ),
  ( Sym: 259; Act: 72 ),
  ( Sym: 260; Act: 73 ),
  ( Sym: 268; Act: 108 ),
  ( Sym: 0; Act: -93 ),
  ( Sym: 59; Act: -93 ),
  ( Sym: 124; Act: -93 ),
  ( Sym: 258; Act: -93 ),
  ( Sym: 269; Act: -93 ),
{ 111: }
{ 112: }
{ 113: }
  ( Sym: 125; Act: 119 ),
  ( Sym: 256; Act: 120 ),
{ 114: }
{ 115: }
{ 116: }
{ 117: }
  ( Sym: 59; Act: 112 ),
  ( Sym: 0; Act: -80 ),
  ( Sym: 124; Act: -80 ),
  ( Sym: 256; Act: -80 ),
  ( Sym: 258; Act: -80 ),
  ( Sym: 269; Act: -80 ),
{ 118: }
{ 119: }
{ 120: }
{ 121: }
  ( Sym: 61; Act: 105 ),
  ( Sym: 123; Act: 106 ),
  ( Sym: 0; Act: -101 ),
  ( Sym: 59; Act: -101 ),
  ( Sym: 124; Act: -101 ),
  ( Sym: 256; Act: -101 ),
  ( Sym: 258; Act: -101 ),
  ( Sym: 269; Act: -101 ),
{ 122: }
  ( Sym: 61; Act: 105 ),
  ( Sym: 123; Act: 106 ),
  ( Sym: 0; Act: -101 ),
  ( Sym: 59; Act: -101 ),
  ( Sym: 124; Act: -101 ),
  ( Sym: 256; Act: -101 ),
  ( Sym: 258; Act: -101 ),
  ( Sym: 269; Act: -101 ),
{ 123: }
  ( Sym: 61; Act: 105 ),
  ( Sym: 123; Act: 106 ),
  ( Sym: 0; Act: -101 ),
  ( Sym: 59; Act: -101 ),
  ( Sym: 124; Act: -101 ),
  ( Sym: 256; Act: -101 ),
  ( Sym: 258; Act: -101 ),
  ( Sym: 269; Act: -101 )
{ 124: }
{ 125: }
{ 126: }
{ 127: }
);

YYG : array [1..YYNGotos] of TYYARec = (
{ 0: }
  ( Sym: -27; Act: 1 ),
  ( Sym: -2; Act: 2 ),
{ 1: }
  ( Sym: -32; Act: 3 ),
  ( Sym: -16; Act: 4 ),
  ( Sym: -15; Act: 5 ),
  ( Sym: -13; Act: 6 ),
  ( Sym: -12; Act: 7 ),
  ( Sym: -11; Act: 8 ),
  ( Sym: -10; Act: 9 ),
  ( Sym: -9; Act: 10 ),
  ( Sym: -8; Act: 11 ),
{ 2: }
{ 3: }
{ 4: }
  ( Sym: -33; Act: 21 ),
{ 5: }
  ( Sym: -29; Act: 22 ),
{ 6: }
  ( Sym: -3; Act: 23 ),
{ 7: }
  ( Sym: -34; Act: 26 ),
  ( Sym: -24; Act: 27 ),
{ 8: }
  ( Sym: -39; Act: 29 ),
{ 9: }
  ( Sym: -38; Act: 30 ),
{ 10: }
  ( Sym: -37; Act: 31 ),
{ 11: }
  ( Sym: -35; Act: 32 ),
{ 12: }
{ 13: }
{ 14: }
{ 15: }
{ 16: }
{ 17: }
{ 18: }
{ 19: }
{ 20: }
{ 21: }
  ( Sym: -17; Act: 33 ),
{ 22: }
  ( Sym: -44; Act: 36 ),
  ( Sym: -28; Act: 37 ),
  ( Sym: -16; Act: 38 ),
{ 23: }
{ 24: }
{ 25: }
{ 26: }
  ( Sym: -42; Act: 40 ),
  ( Sym: -40; Act: 41 ),
  ( Sym: -3; Act: 42 ),
{ 27: }
  ( Sym: -3; Act: 44 ),
{ 28: }
{ 29: }
  ( Sym: -34; Act: 45 ),
  ( Sym: -24; Act: 27 ),
{ 30: }
  ( Sym: -34; Act: 46 ),
  ( Sym: -24; Act: 27 ),
{ 31: }
  ( Sym: -34; Act: 47 ),
  ( Sym: -24; Act: 27 ),
{ 32: }
  ( Sym: -34; Act: 48 ),
  ( Sym: -24; Act: 27 ),
{ 33: }
{ 34: }
{ 35: }
{ 36: }
  ( Sym: -43; Act: 49 ),
  ( Sym: -4; Act: 50 ),
{ 37: }
  ( Sym: -47; Act: 52 ),
  ( Sym: -43; Act: 53 ),
  ( Sym: -31; Act: 54 ),
  ( Sym: -21; Act: 55 ),
  ( Sym: -4; Act: 50 ),
{ 38: }
  ( Sym: -45; Act: 58 ),
{ 39: }
{ 40: }
{ 41: }
  ( Sym: -42; Act: 59 ),
  ( Sym: -18; Act: 60 ),
  ( Sym: -3; Act: 42 ),
{ 42: }
{ 43: }
{ 44: }
  ( Sym: -25; Act: 63 ),
{ 45: }
  ( Sym: -41; Act: 66 ),
  ( Sym: -36; Act: 67 ),
  ( Sym: -6; Act: 68 ),
  ( Sym: -5; Act: 69 ),
  ( Sym: -3; Act: 70 ),
{ 46: }
  ( Sym: -41; Act: 66 ),
  ( Sym: -36; Act: 74 ),
  ( Sym: -6; Act: 68 ),
  ( Sym: -5; Act: 69 ),
  ( Sym: -3; Act: 70 ),
{ 47: }
  ( Sym: -41; Act: 66 ),
  ( Sym: -36; Act: 75 ),
  ( Sym: -6; Act: 68 ),
  ( Sym: -5; Act: 69 ),
  ( Sym: -3; Act: 70 ),
{ 48: }
  ( Sym: -41; Act: 66 ),
  ( Sym: -36; Act: 76 ),
  ( Sym: -6; Act: 68 ),
  ( Sym: -5; Act: 69 ),
  ( Sym: -3; Act: 70 ),
{ 49: }
{ 50: }
  ( Sym: -48; Act: 77 ),
{ 51: }
{ 52: }
{ 53: }
{ 54: }
  ( Sym: -30; Act: 78 ),
  ( Sym: -15; Act: 79 ),
{ 55: }
  ( Sym: -52; Act: 80 ),
{ 56: }
{ 57: }
{ 58: }
  ( Sym: -17; Act: 81 ),
{ 59: }
{ 60: }
  ( Sym: -42; Act: 82 ),
  ( Sym: -3; Act: 42 ),
{ 61: }
{ 62: }
{ 63: }
{ 64: }
{ 65: }
{ 66: }
{ 67: }
  ( Sym: -41; Act: 84 ),
  ( Sym: -18; Act: 85 ),
  ( Sym: -6; Act: 68 ),
  ( Sym: -5; Act: 69 ),
  ( Sym: -3; Act: 70 ),
{ 68: }
  ( Sym: -7; Act: 87 ),
{ 69: }
{ 70: }
  ( Sym: -7; Act: 89 ),
{ 71: }
{ 72: }
{ 73: }
{ 74: }
  ( Sym: -41; Act: 84 ),
  ( Sym: -18; Act: 85 ),
  ( Sym: -6; Act: 68 ),
  ( Sym: -5; Act: 69 ),
  ( Sym: -3; Act: 70 ),
{ 75: }
  ( Sym: -41; Act: 84 ),
  ( Sym: -18; Act: 85 ),
  ( Sym: -6; Act: 68 ),
  ( Sym: -5; Act: 69 ),
  ( Sym: -3; Act: 70 ),
{ 76: }
  ( Sym: -41; Act: 84 ),
  ( Sym: -18; Act: 85 ),
  ( Sym: -6; Act: 68 ),
  ( Sym: -5; Act: 69 ),
  ( Sym: -3; Act: 70 ),
{ 77: }
  ( Sym: -19; Act: 90 ),
{ 78: }
{ 79: }
{ 80: }
  ( Sym: -49; Act: 92 ),
{ 81: }
  ( Sym: -46; Act: 93 ),
{ 82: }
{ 83: }
{ 84: }
{ 85: }
  ( Sym: -41; Act: 94 ),
  ( Sym: -6; Act: 68 ),
  ( Sym: -5; Act: 69 ),
  ( Sym: -3; Act: 70 ),
{ 86: }
{ 87: }
{ 88: }
{ 89: }
{ 90: }
  ( Sym: -50; Act: 96 ),
{ 91: }
{ 92: }
  ( Sym: -53; Act: 97 ),
  ( Sym: -51; Act: 98 ),
  ( Sym: -26; Act: 99 ),
  ( Sym: -22; Act: 100 ),
  ( Sym: -14; Act: 101 ),
  ( Sym: -6; Act: 102 ),
  ( Sym: -5; Act: 103 ),
  ( Sym: -3; Act: 104 ),
{ 93: }
  ( Sym: -43; Act: 109 ),
  ( Sym: -4; Act: 50 ),
{ 94: }
{ 95: }
{ 96: }
  ( Sym: -49; Act: 110 ),
{ 97: }
{ 98: }
  ( Sym: -20; Act: 111 ),
{ 99: }
{ 100: }
  ( Sym: -54; Act: 113 ),
{ 101: }
  ( Sym: -6; Act: 114 ),
  ( Sym: -5; Act: 115 ),
  ( Sym: -3; Act: 116 ),
{ 102: }
{ 103: }
{ 104: }
{ 105: }
{ 106: }
{ 107: }
{ 108: }
{ 109: }
{ 110: }
  ( Sym: -53; Act: 97 ),
  ( Sym: -51; Act: 117 ),
  ( Sym: -26; Act: 99 ),
  ( Sym: -22; Act: 100 ),
  ( Sym: -14; Act: 101 ),
  ( Sym: -6; Act: 102 ),
  ( Sym: -5; Act: 103 ),
  ( Sym: -3; Act: 104 ),
{ 111: }
{ 112: }
{ 113: }
  ( Sym: -23; Act: 118 ),
{ 114: }
  ( Sym: -57; Act: 121 ),
{ 115: }
  ( Sym: -56; Act: 122 ),
{ 116: }
  ( Sym: -58; Act: 123 ),
{ 117: }
  ( Sym: -20; Act: 111 ),
{ 118: }
{ 119: }
{ 120: }
{ 121: }
  ( Sym: -55; Act: 124 ),
  ( Sym: -53; Act: 125 ),
  ( Sym: -26; Act: 99 ),
  ( Sym: -22; Act: 100 ),
{ 122: }
  ( Sym: -55; Act: 126 ),
  ( Sym: -53; Act: 125 ),
  ( Sym: -26; Act: 99 ),
  ( Sym: -22; Act: 100 ),
{ 123: }
  ( Sym: -55; Act: 127 ),
  ( Sym: -53; Act: 125 ),
  ( Sym: -26; Act: 99 ),
  ( Sym: -22; Act: 100 )
{ 124: }
{ 125: }
{ 126: }
{ 127: }
);

YYD : array [0..YYNStates-1] of Integer = (
{ 0: } -33,
{ 1: } 0,
{ 2: } 0,
{ 3: } -34,
{ 4: } -38,
{ 5: } -28,
{ 6: } 0,
{ 7: } 0,
{ 8: } -46,
{ 9: } -44,
{ 10: } -42,
{ 11: } -40,
{ 12: } -35,
{ 13: } -6,
{ 14: } -7,
{ 15: } -8,
{ 16: } -9,
{ 17: } -10,
{ 18: } -11,
{ 19: } -13,
{ 20: } -14,
{ 21: } 0,
{ 22: } 0,
{ 23: } -36,
{ 24: } -37,
{ 25: } -1,
{ 26: } 0,
{ 27: } 0,
{ 28: } -24,
{ 29: } 0,
{ 30: } 0,
{ 31: } 0,
{ 32: } 0,
{ 33: } -39,
{ 34: } -16,
{ 35: } -15,
{ 36: } 0,
{ 37: } 0,
{ 38: } -72,
{ 39: } -76,
{ 40: } -63,
{ 41: } 0,
{ 42: } -69,
{ 43: } -66,
{ 44: } 0,
{ 45: } 0,
{ 46: } 0,
{ 47: } 0,
{ 48: } 0,
{ 49: } -71,
{ 50: } -78,
{ 51: } -2,
{ 52: } -75,
{ 53: } -81,
{ 54: } 0,
{ 55: } -82,
{ 56: } -20,
{ 57: } -77,
{ 58: } 0,
{ 59: } -64,
{ 60: } 0,
{ 61: } -17,
{ 62: } -67,
{ 63: } -51,
{ 64: } -25,
{ 65: } -26,
{ 66: } -52,
{ 67: } 0,
{ 68: } 0,
{ 69: } -58,
{ 70: } 0,
{ 71: } -55,
{ 72: } -3,
{ 73: } -4,
{ 74: } 0,
{ 75: } 0,
{ 76: } 0,
{ 77: } 0,
{ 78: } -30,
{ 79: } -32,
{ 80: } -84,
{ 81: } -73,
{ 82: } -65,
{ 83: } -68,
{ 84: } -53,
{ 85: } 0,
{ 86: } -56,
{ 87: } -61,
{ 88: } -5,
{ 89: } -62,
{ 90: } -79,
{ 91: } -18,
{ 92: } 0,
{ 93: } 0,
{ 94: } -54,
{ 95: } -57,
{ 96: } -84,
{ 97: } -88,
{ 98: } 0,
{ 99: } -92,
{ 100: } -90,
{ 101: } 0,
{ 102: } -86,
{ 103: } -85,
{ 104: } -87,
{ 105: } -27,
{ 106: } -21,
{ 107: } -89,
{ 108: } -12,
{ 109: } -74,
{ 110: } 0,
{ 111: } -100,
{ 112: } -19,
{ 113: } 0,
{ 114: } -96,
{ 115: } -94,
{ 116: } -98,
{ 117: } 0,
{ 118: } -91,
{ 119: } -22,
{ 120: } -23,
{ 121: } 0,
{ 122: } 0,
{ 123: } 0,
{ 124: } -97,
{ 125: } -102,
{ 126: } -95,
{ 127: } -99
);

YYAL : array [0..YYNStates-1] of Integer = (
{ 0: } 1,
{ 1: } 1,
{ 2: } 10,
{ 3: } 11,
{ 4: } 11,
{ 5: } 11,
{ 6: } 11,
{ 7: } 13,
{ 8: } 24,
{ 9: } 24,
{ 10: } 24,
{ 11: } 24,
{ 12: } 24,
{ 13: } 24,
{ 14: } 24,
{ 15: } 24,
{ 16: } 24,
{ 17: } 24,
{ 18: } 24,
{ 19: } 24,
{ 20: } 24,
{ 21: } 24,
{ 22: } 26,
{ 23: } 29,
{ 24: } 29,
{ 25: } 29,
{ 26: } 29,
{ 27: } 39,
{ 28: } 40,
{ 29: } 40,
{ 30: } 45,
{ 31: } 50,
{ 32: } 55,
{ 33: } 60,
{ 34: } 60,
{ 35: } 60,
{ 36: } 60,
{ 37: } 61,
{ 38: } 66,
{ 39: } 66,
{ 40: } 66,
{ 41: } 66,
{ 42: } 77,
{ 43: } 77,
{ 44: } 77,
{ 45: } 79,
{ 46: } 83,
{ 47: } 87,
{ 48: } 91,
{ 49: } 95,
{ 50: } 95,
{ 51: } 95,
{ 52: } 95,
{ 53: } 95,
{ 54: } 95,
{ 55: } 97,
{ 56: } 97,
{ 57: } 97,
{ 58: } 97,
{ 59: } 99,
{ 60: } 99,
{ 61: } 101,
{ 62: } 101,
{ 63: } 101,
{ 64: } 101,
{ 65: } 101,
{ 66: } 101,
{ 67: } 101,
{ 68: } 114,
{ 69: } 128,
{ 70: } 128,
{ 71: } 142,
{ 72: } 142,
{ 73: } 142,
{ 74: } 142,
{ 75: } 155,
{ 76: } 168,
{ 77: } 181,
{ 78: } 182,
{ 79: } 182,
{ 80: } 182,
{ 81: } 182,
{ 82: } 182,
{ 83: } 182,
{ 84: } 182,
{ 85: } 182,
{ 86: } 186,
{ 87: } 186,
{ 88: } 186,
{ 89: } 186,
{ 90: } 186,
{ 91: } 186,
{ 92: } 186,
{ 93: } 198,
{ 94: } 199,
{ 95: } 199,
{ 96: } 199,
{ 97: } 199,
{ 98: } 199,
{ 99: } 205,
{ 100: } 205,
{ 101: } 205,
{ 102: } 208,
{ 103: } 208,
{ 104: } 208,
{ 105: } 208,
{ 106: } 208,
{ 107: } 208,
{ 108: } 208,
{ 109: } 208,
{ 110: } 208,
{ 111: } 220,
{ 112: } 220,
{ 113: } 220,
{ 114: } 222,
{ 115: } 222,
{ 116: } 222,
{ 117: } 222,
{ 118: } 228,
{ 119: } 228,
{ 120: } 228,
{ 121: } 228,
{ 122: } 236,
{ 123: } 244,
{ 124: } 252,
{ 125: } 252,
{ 126: } 252,
{ 127: } 252
);

YYAH : array [0..YYNStates-1] of Integer = (
{ 0: } 0,
{ 1: } 9,
{ 2: } 10,
{ 3: } 10,
{ 4: } 10,
{ 5: } 10,
{ 6: } 12,
{ 7: } 23,
{ 8: } 23,
{ 9: } 23,
{ 10: } 23,
{ 11: } 23,
{ 12: } 23,
{ 13: } 23,
{ 14: } 23,
{ 15: } 23,
{ 16: } 23,
{ 17: } 23,
{ 18: } 23,
{ 19: } 23,
{ 20: } 23,
{ 21: } 25,
{ 22: } 28,
{ 23: } 28,
{ 24: } 28,
{ 25: } 28,
{ 26: } 38,
{ 27: } 39,
{ 28: } 39,
{ 29: } 44,
{ 30: } 49,
{ 31: } 54,
{ 32: } 59,
{ 33: } 59,
{ 34: } 59,
{ 35: } 59,
{ 36: } 60,
{ 37: } 65,
{ 38: } 65,
{ 39: } 65,
{ 40: } 65,
{ 41: } 76,
{ 42: } 76,
{ 43: } 76,
{ 44: } 78,
{ 45: } 82,
{ 46: } 86,
{ 47: } 90,
{ 48: } 94,
{ 49: } 94,
{ 50: } 94,
{ 51: } 94,
{ 52: } 94,
{ 53: } 94,
{ 54: } 96,
{ 55: } 96,
{ 56: } 96,
{ 57: } 96,
{ 58: } 98,
{ 59: } 98,
{ 60: } 100,
{ 61: } 100,
{ 62: } 100,
{ 63: } 100,
{ 64: } 100,
{ 65: } 100,
{ 66: } 100,
{ 67: } 113,
{ 68: } 127,
{ 69: } 127,
{ 70: } 141,
{ 71: } 141,
{ 72: } 141,
{ 73: } 141,
{ 74: } 154,
{ 75: } 167,
{ 76: } 180,
{ 77: } 181,
{ 78: } 181,
{ 79: } 181,
{ 80: } 181,
{ 81: } 181,
{ 82: } 181,
{ 83: } 181,
{ 84: } 181,
{ 85: } 185,
{ 86: } 185,
{ 87: } 185,
{ 88: } 185,
{ 89: } 185,
{ 90: } 185,
{ 91: } 185,
{ 92: } 197,
{ 93: } 198,
{ 94: } 198,
{ 95: } 198,
{ 96: } 198,
{ 97: } 198,
{ 98: } 204,
{ 99: } 204,
{ 100: } 204,
{ 101: } 207,
{ 102: } 207,
{ 103: } 207,
{ 104: } 207,
{ 105: } 207,
{ 106: } 207,
{ 107: } 207,
{ 108: } 207,
{ 109: } 207,
{ 110: } 219,
{ 111: } 219,
{ 112: } 219,
{ 113: } 221,
{ 114: } 221,
{ 115: } 221,
{ 116: } 221,
{ 117: } 227,
{ 118: } 227,
{ 119: } 227,
{ 120: } 227,
{ 121: } 235,
{ 122: } 243,
{ 123: } 251,
{ 124: } 251,
{ 125: } 251,
{ 126: } 251,
{ 127: } 251
);

YYGL : array [0..YYNStates-1] of Integer = (
{ 0: } 1,
{ 1: } 3,
{ 2: } 12,
{ 3: } 12,
{ 4: } 12,
{ 5: } 13,
{ 6: } 14,
{ 7: } 15,
{ 8: } 17,
{ 9: } 18,
{ 10: } 19,
{ 11: } 20,
{ 12: } 21,
{ 13: } 21,
{ 14: } 21,
{ 15: } 21,
{ 16: } 21,
{ 17: } 21,
{ 18: } 21,
{ 19: } 21,
{ 20: } 21,
{ 21: } 21,
{ 22: } 22,
{ 23: } 25,
{ 24: } 25,
{ 25: } 25,
{ 26: } 25,
{ 27: } 28,
{ 28: } 29,
{ 29: } 29,
{ 30: } 31,
{ 31: } 33,
{ 32: } 35,
{ 33: } 37,
{ 34: } 37,
{ 35: } 37,
{ 36: } 37,
{ 37: } 39,
{ 38: } 44,
{ 39: } 45,
{ 40: } 45,
{ 41: } 45,
{ 42: } 48,
{ 43: } 48,
{ 44: } 48,
{ 45: } 49,
{ 46: } 54,
{ 47: } 59,
{ 48: } 64,
{ 49: } 69,
{ 50: } 69,
{ 51: } 70,
{ 52: } 70,
{ 53: } 70,
{ 54: } 70,
{ 55: } 72,
{ 56: } 73,
{ 57: } 73,
{ 58: } 73,
{ 59: } 74,
{ 60: } 74,
{ 61: } 76,
{ 62: } 76,
{ 63: } 76,
{ 64: } 76,
{ 65: } 76,
{ 66: } 76,
{ 67: } 76,
{ 68: } 81,
{ 69: } 82,
{ 70: } 82,
{ 71: } 83,
{ 72: } 83,
{ 73: } 83,
{ 74: } 83,
{ 75: } 88,
{ 76: } 93,
{ 77: } 98,
{ 78: } 99,
{ 79: } 99,
{ 80: } 99,
{ 81: } 100,
{ 82: } 101,
{ 83: } 101,
{ 84: } 101,
{ 85: } 101,
{ 86: } 105,
{ 87: } 105,
{ 88: } 105,
{ 89: } 105,
{ 90: } 105,
{ 91: } 106,
{ 92: } 106,
{ 93: } 114,
{ 94: } 116,
{ 95: } 116,
{ 96: } 116,
{ 97: } 117,
{ 98: } 117,
{ 99: } 118,
{ 100: } 118,
{ 101: } 119,
{ 102: } 122,
{ 103: } 122,
{ 104: } 122,
{ 105: } 122,
{ 106: } 122,
{ 107: } 122,
{ 108: } 122,
{ 109: } 122,
{ 110: } 122,
{ 111: } 130,
{ 112: } 130,
{ 113: } 130,
{ 114: } 131,
{ 115: } 132,
{ 116: } 133,
{ 117: } 134,
{ 118: } 135,
{ 119: } 135,
{ 120: } 135,
{ 121: } 135,
{ 122: } 139,
{ 123: } 143,
{ 124: } 147,
{ 125: } 147,
{ 126: } 147,
{ 127: } 147
);

YYGH : array [0..YYNStates-1] of Integer = (
{ 0: } 2,
{ 1: } 11,
{ 2: } 11,
{ 3: } 11,
{ 4: } 12,
{ 5: } 13,
{ 6: } 14,
{ 7: } 16,
{ 8: } 17,
{ 9: } 18,
{ 10: } 19,
{ 11: } 20,
{ 12: } 20,
{ 13: } 20,
{ 14: } 20,
{ 15: } 20,
{ 16: } 20,
{ 17: } 20,
{ 18: } 20,
{ 19: } 20,
{ 20: } 20,
{ 21: } 21,
{ 22: } 24,
{ 23: } 24,
{ 24: } 24,
{ 25: } 24,
{ 26: } 27,
{ 27: } 28,
{ 28: } 28,
{ 29: } 30,
{ 30: } 32,
{ 31: } 34,
{ 32: } 36,
{ 33: } 36,
{ 34: } 36,
{ 35: } 36,
{ 36: } 38,
{ 37: } 43,
{ 38: } 44,
{ 39: } 44,
{ 40: } 44,
{ 41: } 47,
{ 42: } 47,
{ 43: } 47,
{ 44: } 48,
{ 45: } 53,
{ 46: } 58,
{ 47: } 63,
{ 48: } 68,
{ 49: } 68,
{ 50: } 69,
{ 51: } 69,
{ 52: } 69,
{ 53: } 69,
{ 54: } 71,
{ 55: } 72,
{ 56: } 72,
{ 57: } 72,
{ 58: } 73,
{ 59: } 73,
{ 60: } 75,
{ 61: } 75,
{ 62: } 75,
{ 63: } 75,
{ 64: } 75,
{ 65: } 75,
{ 66: } 75,
{ 67: } 80,
{ 68: } 81,
{ 69: } 81,
{ 70: } 82,
{ 71: } 82,
{ 72: } 82,
{ 73: } 82,
{ 74: } 87,
{ 75: } 92,
{ 76: } 97,
{ 77: } 98,
{ 78: } 98,
{ 79: } 98,
{ 80: } 99,
{ 81: } 100,
{ 82: } 100,
{ 83: } 100,
{ 84: } 100,
{ 85: } 104,
{ 86: } 104,
{ 87: } 104,
{ 88: } 104,
{ 89: } 104,
{ 90: } 105,
{ 91: } 105,
{ 92: } 113,
{ 93: } 115,
{ 94: } 115,
{ 95: } 115,
{ 96: } 116,
{ 97: } 116,
{ 98: } 117,
{ 99: } 117,
{ 100: } 118,
{ 101: } 121,
{ 102: } 121,
{ 103: } 121,
{ 104: } 121,
{ 105: } 121,
{ 106: } 121,
{ 107: } 121,
{ 108: } 121,
{ 109: } 121,
{ 110: } 129,
{ 111: } 129,
{ 112: } 129,
{ 113: } 130,
{ 114: } 131,
{ 115: } 132,
{ 116: } 133,
{ 117: } 134,
{ 118: } 134,
{ 119: } 134,
{ 120: } 134,
{ 121: } 138,
{ 122: } 142,
{ 123: } 146,
{ 124: } 146,
{ 125: } 146,
{ 126: } 146,
{ 127: } 146
);

YYR : array [1..YYNRules] of TYYRRec = (
{ 1: } ( Len: 1; Sym: -3 ),
{ 2: } ( Len: 1; Sym: -4 ),
{ 3: } ( Len: 1; Sym: -5 ),
{ 4: } ( Len: 1; Sym: -6 ),
{ 5: } ( Len: 1; Sym: -7 ),
{ 6: } ( Len: 1; Sym: -8 ),
{ 7: } ( Len: 1; Sym: -9 ),
{ 8: } ( Len: 1; Sym: -10 ),
{ 9: } ( Len: 1; Sym: -11 ),
{ 10: } ( Len: 1; Sym: -12 ),
{ 11: } ( Len: 1; Sym: -13 ),
{ 12: } ( Len: 1; Sym: -14 ),
{ 13: } ( Len: 1; Sym: -15 ),
{ 14: } ( Len: 1; Sym: -16 ),
{ 15: } ( Len: 1; Sym: -17 ),
{ 16: } ( Len: 1; Sym: -17 ),
{ 17: } ( Len: 1; Sym: -18 ),
{ 18: } ( Len: 1; Sym: -19 ),
{ 19: } ( Len: 1; Sym: -20 ),
{ 20: } ( Len: 1; Sym: -21 ),
{ 21: } ( Len: 1; Sym: -22 ),
{ 22: } ( Len: 1; Sym: -23 ),
{ 23: } ( Len: 1; Sym: -23 ),
{ 24: } ( Len: 1; Sym: -24 ),
{ 25: } ( Len: 1; Sym: -25 ),
{ 26: } ( Len: 1; Sym: -25 ),
{ 27: } ( Len: 1; Sym: -26 ),
{ 28: } ( Len: 0; Sym: -29 ),
{ 29: } ( Len: 0; Sym: -31 ),
{ 30: } ( Len: 6; Sym: -2 ),
{ 31: } ( Len: 0; Sym: -30 ),
{ 32: } ( Len: 1; Sym: -30 ),
{ 33: } ( Len: 0; Sym: -27 ),
{ 34: } ( Len: 2; Sym: -27 ),
{ 35: } ( Len: 2; Sym: -27 ),
{ 36: } ( Len: 2; Sym: -32 ),
{ 37: } ( Len: 2; Sym: -32 ),
{ 38: } ( Len: 0; Sym: -33 ),
{ 39: } ( Len: 3; Sym: -32 ),
{ 40: } ( Len: 0; Sym: -35 ),
{ 41: } ( Len: 4; Sym: -32 ),
{ 42: } ( Len: 0; Sym: -37 ),
{ 43: } ( Len: 4; Sym: -32 ),
{ 44: } ( Len: 0; Sym: -38 ),
{ 45: } ( Len: 4; Sym: -32 ),
{ 46: } ( Len: 0; Sym: -39 ),
{ 47: } ( Len: 4; Sym: -32 ),
{ 48: } ( Len: 3; Sym: -32 ),
{ 49: } ( Len: 2; Sym: -32 ),
{ 50: } ( Len: 0; Sym: -34 ),
{ 51: } ( Len: 3; Sym: -34 ),
{ 52: } ( Len: 1; Sym: -36 ),
{ 53: } ( Len: 2; Sym: -36 ),
{ 54: } ( Len: 3; Sym: -36 ),
{ 55: } ( Len: 1; Sym: -36 ),
{ 56: } ( Len: 2; Sym: -36 ),
{ 57: } ( Len: 3; Sym: -36 ),
{ 58: } ( Len: 1; Sym: -41 ),
{ 59: } ( Len: 1; Sym: -41 ),
{ 60: } ( Len: 1; Sym: -41 ),
{ 61: } ( Len: 2; Sym: -41 ),
{ 62: } ( Len: 2; Sym: -41 ),
{ 63: } ( Len: 1; Sym: -40 ),
{ 64: } ( Len: 2; Sym: -40 ),
{ 65: } ( Len: 3; Sym: -40 ),
{ 66: } ( Len: 1; Sym: -40 ),
{ 67: } ( Len: 2; Sym: -40 ),
{ 68: } ( Len: 3; Sym: -40 ),
{ 69: } ( Len: 1; Sym: -42 ),
{ 70: } ( Len: 0; Sym: -44 ),
{ 71: } ( Len: 2; Sym: -28 ),
{ 72: } ( Len: 0; Sym: -45 ),
{ 73: } ( Len: 0; Sym: -46 ),
{ 74: } ( Len: 5; Sym: -28 ),
{ 75: } ( Len: 2; Sym: -28 ),
{ 76: } ( Len: 1; Sym: -28 ),
{ 77: } ( Len: 2; Sym: -28 ),
{ 78: } ( Len: 0; Sym: -48 ),
{ 79: } ( Len: 0; Sym: -50 ),
{ 80: } ( Len: 6; Sym: -43 ),
{ 81: } ( Len: 1; Sym: -47 ),
{ 82: } ( Len: 0; Sym: -52 ),
{ 83: } ( Len: 4; Sym: -47 ),
{ 84: } ( Len: 0; Sym: -49 ),
{ 85: } ( Len: 2; Sym: -49 ),
{ 86: } ( Len: 2; Sym: -49 ),
{ 87: } ( Len: 2; Sym: -49 ),
{ 88: } ( Len: 2; Sym: -49 ),
{ 89: } ( Len: 2; Sym: -49 ),
{ 90: } ( Len: 0; Sym: -54 ),
{ 91: } ( Len: 3; Sym: -53 ),
{ 92: } ( Len: 1; Sym: -53 ),
{ 93: } ( Len: 0; Sym: -51 ),
{ 94: } ( Len: 0; Sym: -56 ),
{ 95: } ( Len: 4; Sym: -51 ),
{ 96: } ( Len: 0; Sym: -57 ),
{ 97: } ( Len: 4; Sym: -51 ),
{ 98: } ( Len: 0; Sym: -58 ),
{ 99: } ( Len: 4; Sym: -51 ),
{ 100: } ( Len: 2; Sym: -51 ),
{ 101: } ( Len: 0; Sym: -55 ),
{ 102: } ( Len: 1; Sym: -55 )
);


const ParserErrorFlag = 256; (* error token *)

function YYAct(State, Sym : Integer; var Act : Integer) : Boolean;
  (* search action table *)
  var K : Integer;
  begin
    K := YYAL[State];
    while (K<=YYAH[State]) and (YYA[K].Sym<>Sym) do Inc(K);
    if K>YYAH[State] then
      YYAct := False
    else
      begin
        Act := YYA[K].Act;
        YYAct := True;
      end;
  end(*yyact*);

function YYGoto(State, Sym : Integer; var NState : Integer) : Boolean;
  (* search goto table *)
  var K : Integer;
  begin
    K := YYGL[State];
    while (K<=YYGH[State]) and (YYG[K].Sym<>Sym) do Inc(K);
    if K>YYGH[State] then
      YYGoto := False
    else
      begin
        NState := YYG[K].Act;
        YYGoto := True;
      end;
  end(*yygoto*);

label Parse, Next, Error, ErrLab, Shift, Reduce, Accept, Abort;

begin(*yyparse*)

  (* initialize: *)

  YYState := 0; YYChar := -1; YYNErrs := 0; YYErrFlag := 0; YYSP := 0;

{$ifdef yydebug}
  YYDebug := True;
{$else}
  YYDebug := False;
{$endif}

Parse:

  (* push state and value: *)

  Inc(YYSP);
  if YYSP>YYMaxDepth then
    begin
      yyerror('yyparse stack overflow');
      goto Abort;
    end;
  YYS[YYSP] := YYState; YYV[YYSP] := yyval;

Next:

  if (YYD[YYState]=0) and (YYChar=-1) then
    (* get next symbol *)
    begin
      YYChar := yylex; if YYChar<0 then YYChar := 0;
    end;

  if YYDebug then WriteLn('state ', YYState, ', char ', YYChar);

  (* determine parse action: *)

  YYN := YYD[YYState];
  if YYN<>0 then goto Reduce; (* simple state *)

  (* no default action; search parse table *)

  if not YYAct(YYState, YYChar, YYN) then goto Error
  else if YYN>0 then                      goto Shift
  else if YYN<0 then                      goto Reduce
  else                                    goto Accept;

Error:

  (* error; start error recovery: *)

  if YYErrFlag=0 then yyerror('syntax error');

ErrLab:

  if YYErrFlag=0 then Inc(YYNErrs);     (* new error *)

  if YYErrFlag<=2 then                  (* incomplete recovery; try again *)
    begin
      YYErrFlag := 3;
      (* uncover a state with shift action on error token *)
      while (YYSP>0) and not ( YYAct(YYS[YYSP], ParserErrorFlag, YYN) and
                               (YYN>0) ) do
        begin
          if YYDebug then
            if YYSP>1 then
              WriteLn('error recovery pops state ', YYS[YYSP], ', uncovers ',
                      YYS[YYSP-1])
            else
              WriteLn('error recovery fails ... abort');
          Dec(YYSP);
        end;
      if YYSP=0 then goto Abort; (* parser has fallen from stack; abort *)
      YYState := YYN;            (* simulate shift on error *)
      goto Parse;
    end
  else                                  (* no shift yet; discard symbol *)
    begin
      if YYDebug then WriteLn('error recovery discards char ', YYChar);
      if YYChar=0 then goto Abort; (* end of input; abort *)
      YYChar := -1; goto Next;     (* clear lookahead char and try again *)
    end;

Shift:

  (* go to new state, clear lookahead character: *)

  YYState := YYN; YYChar := -1; yyval := yylval;
  if YYErrFlag>0 then Dec(YYErrFlag);

  goto Parse;

Reduce:

  (* execute action, pop rule from stack, and go to next state: *)

  if YYDebug then WriteLn('reduce ', -YYN);

  YYFlag := yyfnone; YYAction(-YYN);
  Dec(YYSP, YYR[-YYN].Len);
  if YYGoto(YYS[YYSP], YYR[-YYN].Sym, YYN) then YYState := YYN;

  (* handle action calls to yyaccept, yyabort and yyerror: *)

  case YYFlag of
    yyfaccept : goto Accept;
    yyfabort  : goto Abort;
    yyferror  : goto ErrLab;
  end;

  goto Parse;

Accept:

  yyparse := 0; Exit;

Abort:

  yyparse := 1; Exit;

end(*yyparse*);


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
      (* table of Yacc keywords (unstopped): *)
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