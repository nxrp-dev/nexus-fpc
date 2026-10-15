{
  TP Lex message and error handling module
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
$Modtime: 96-08-01 8:52 $

$History: LEXMSGS.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit LexMsgs;

interface


var Errors, Warnings : Integer;
  (* - current error and warning count *)
procedure Error(Msg : String; POS : Integer);
  (* - print current input line and error message (pos denotes position to
       mark in source file line) *)
procedure Warning(Msg : String; POS : Integer);
  (* - print warning message *)
procedure Fatal(Msg : String);
  (* - writes a fatal error message, erases Lex output file and terminates
       the program with errorlevel 1 *)

const

(* sign-on and usage message: *)

SignOn = 'TP Lex Version 4.1a [April 2000], Copyright (c) 1990-2000 Albert Graef';
{$ifdef Unix}
Usage   = 'Usage: plex [options] lex-file[.l] [output-file[.pas]]';
{$else}
Usage   = 'Usage: lex [options] lex-file[.l] [output-file[.pas]]';
{$endif}
Options = 'Options: -v verbose, -o optimize';

(* command line error messages: *)

InvalidOption                  = 'invalid option ';
IllegalNoArgs                 = 'illegal number of parameters';

(* syntax errors: *)

UnmatchedLBrace                = '101: unmatched %{';
SyntaxError                    = '102: syntax error';
UnexpectedEOF                  = '103: unexpected end of file';

(* semantic errors: *)

SymbolAlreadyDefined          = '201: symbol already defined';
UndefinedSymbol                = '202: undefined symbol';
InvalidCharNum                 = '203: invalid character number';
EmptyGrammar                   = '204: empty grammar?';

(* fatal errors: *)

CannotOpenFile                = 'FATAL: cannot open file ';
WriteError                     = 'FATAL: write error';
MemOverflow                    = 'FATAL: memory overflow';
IntsetOverflow                 = 'FATAL: integer set overflow';
SymTableOverflow              = 'FATAL: symbol table overflow';
PosTableOverflow              = 'FATAL: position table overflow';
StateTableOverflow            = 'FATAL: state table overflow';
TransTableOverflow            = 'FATAL: transition table overflow';
MacroStackOverflow            = 'FATAL: macro stack overflow';

implementation

uses LexBase;

procedure Position(var F : Text;
            LineNo : Integer;
            Line : String;
            POS : Integer);
  (* writes a position mark of the form
     gfilename (lineno): line
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

procedure Error(Msg : String; POS : Integer);
  begin
    Inc(Errors);
    WriteLn;
    Position(Output, LNo, Line, POS);
    WriteLn(Msg);
    WriteLn(YYLst);
    Position(YYLst, LNo, Line, POS);
    WriteLn(YYLst, Msg);
    if IOResult<>0 then ;
  end(*error*);

procedure Warning(Msg : String; POS : Integer);
  begin
    Inc(Warnings);
    WriteLn;
    Position(Output, LNo, Line, POS);
    WriteLn(Msg);
    WriteLn(YYLst);
    Position(YYLst, LNo, Line, POS);
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
function HeapErrorHandler ( Size : Word ): Integer;
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
end(*LexMsgs*).
