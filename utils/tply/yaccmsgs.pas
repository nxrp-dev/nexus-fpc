{
  TP Yacc message and error handling module 2-5-91 AG
  Note: this module should be USEd by any module using the heap during
        initialization, since it installs a heap error handler (which
        terminates the program with fatal error `memory overflow').


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


$Revision: 1.3 $
$Modtime: 96-07-31 14:50 $

$History: YACCMSGS.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit YaccMsgs;

interface


var Errors, Warnings : Integer;
  (* - current error and warning count *)
procedure Error(Msg : String);
  (* - print current input line and error message (pos denotes position to
       mark in source file line) *)
procedure Warning(Msg : String);
  (* - print warning message *)
procedure Fatal(Msg : String);
(* - writes a fatal error message, erases Yacc output file and terminates
     the program with errorlevel 1 *)

const

(* sign-on and usage message: *)

SignOn = 'TP Yacc Version 4.1a [April 2000], Copyright (c) 1990-2000 Albert Graef';
{$ifdef Unix}
Usage   = 'Usage: pyacc [options] yacc-file[.y] [output-file[.pas]]';
{$else}
Usage   = 'Usage: yacc [options] yacc-file[.y] [output-file[.pas]]';
{$endif}
Options = 'Options: -v verbose, -d debug';

(* command line error messages: *)

InvalidOption                  = 'invalid option ';
IllegalNoArgs                 = 'illegal number of parameters';

(* syntax errors: *)

OpenCommentAtEOF             = '101: open comment at end of file';
MissingStringTerminator       = '102: missing string terminator';
RCurlExpected                  = '103: %} expected';
RBraceExpected                 = '104: } expected';
RAngleExpected                 = '105: > expected';
IdentExpected                  = '106: identifier expected';
ErrorInDef                    = '110: error in definition';
ErrorInRule                   = '111: error in rule';
SyntaxError                    = '112: syntax error';
UnexpectedEOF                  = '113: unexpected end of file';

(* semantic errors: *)

NonTermExpected                = '201: nonterminal expected';
LiteralExpected                = '202: literal expected';
DoubleTokenNumDef             = '203: literal already defined';
UnknownIdentifier              = '204: unknown identifier';
TypeError                      = '205: type error';
RangeError                     = '206: range error';
EmptyGrammar                   = '207: empty grammar?';

(* fatal errors: *)

CannotOpenFile                = 'FATAL: cannot open file ';
WriteError                     = 'FATAL: write error';
MemOverflow                    = 'FATAL: memory overflow';
IntsetOverflow                 = 'FATAL: integer set overflow';
SymTableOverflow              = 'FATAL: symbol table overflow';
NTTableOverflow               = 'FATAL: nonterminal table overflow';
LitTableOverflow              = 'FATAL: literal table overflow';
TypeTableOverflow             = 'FATAL: type table overflow';
PrecTableOverflow             = 'FATAL: precedence table overflow';
RuleTableOverflow             = 'FATAL: rule table overflow';
StateTableOverflow            = 'FATAL: state table overflow';
ItemTableOverflow             = 'FATAL: item table overflow';
TransTableOverflow            = 'FATAL: transition table overflow';
RednTableOverflow             = 'FATAL: reduction table overflow';

implementation

uses YaccBase;

procedure Position(var F : Text;
            LineNo : Integer;
            Line : String;
            POS : Integer);
  (* writes a position mark of the form
     lineno: line
               ^
     on f with the caret ^ positioned at pos in line
     a subsequent write starts at the next line, indented with tab *)
  var
    Line1, Line2 : String;
  begin
    (* this hack handles tab characters in line: *)
    Line1 := IntStr(LineNo)+': '+Line;
    Line2 := BlankStr(IntStr(LineNo)+': '+Copy(Line, 1, POS-1));
    WriteLn(F, Line1);
    WriteLn(F, Line2, '^');
    Write(F, Tab)
  end(*position*);

procedure Error(Msg : String);
  begin
    Inc(Errors);
    WriteLn;
    Position(Output, LNo, Line, CNo-TokLeng);
    WriteLn(Msg);
    WriteLn(YYLst);
    Position(YYLst, LNo, Line, CNo-TokLeng);
    WriteLn(YYLst, Msg);
    if IOResult<>0 then ;
  end(*error*);

procedure Warning(Msg : String);
  begin
    Inc(Warnings);
    WriteLn;
    Position(Output, LNo, Line, CNo-TokLeng);
    WriteLn(Msg);
    WriteLn(YYLst);
    Position(YYLst, LNo, Line, CNo-TokLeng);
    WriteLn(YYLst, Msg);
    if IOResult<>0 then ;
  end(*warning*);

procedure Fatal(Msg : String);
  begin
    WriteLn;
    WriteLn(Msg);
    Close(YYIn); Close(YYOut); Close(YYLst); Erase(YYOut);
    Halt(1)
  end(*fatal*);

{$ifndef fpc}
{$IFNDEF Win32}
function HeapErrorHandler ( Size : Word ) : Integer;
  begin
    if Size>0 then
      Fatal(MemOverflow) (* never returns *)
    else
      HeapErrorHandler := 1
  end(*heapErrorHandler*);
{$ENDIF}
{$endif}

begin
  Errors := 0; Warnings := 0;
{$ifndef fpc}
{$IFNDEF Win32}
  (* install heap error handler: *)
  HeapError := @HeapErrorHandler;
{$ENDIF}
{$endif}
end(*YaccMsgs*).
