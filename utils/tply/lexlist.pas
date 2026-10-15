{
  Lex listing routines.

  This module provides some routines to produce a readable representation
  of the generated DFA tables (the routines are only used when Lex is run
  with the verbose option /v).

  If this module is compiled with defined conditional `debug', the list file
  will contain extensive debugging output (position table, state positions,
  etc.).


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
$Modtime: 96-08-01 6:28 $

$History: LEXLIST.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit LexList;

interface

uses
  LexBase;


procedure ListDFATable;
  (* list DFA table *)

implementation

uses LexTable;

procedure ListTrans(CC : PCClass; NextState : Integer);
  (* list a transition in the format
        cc : next_state *)
  begin
    Write(YYLst, CClassOrCharStr(CC^):30, ' : ', NextState:5);
  end(*listTrans*);

{$ifdef debug}

procedure ListPosTable;
  (* lists the position table *)
  var
    P, I : Integer;
  begin
    if NPos=0 then Exit;
    WriteLn(YYLst);
    for P := 1 to NPos do
      with PosTable^[P] do
        begin
          Write(YYLst, P:5, '     ');
          if PosType=CharPos then
            Write(YYLst, SingleQuoteStr(C):20)
          else if PosType=CClassPos then
            Write(YYLst, CClassStr(CC^):20)
          else if PosType=MarkPos then
            if POS=0 then
              Write(YYLst, '# (rule '+IntStr(Rule)+')':20)
            else
              Write(YYLst, '/ (rule '+IntStr(Rule)+')':20);
          Write(YYLst, ' ':5);
          for I := 1 to Size(FollowPos^) do
            if FollowPos^[I]>0 then Write(YYLst, FollowPos^[I]:5, ' ');
          WriteLn(YYLst);
        end;
    WriteLn(YYLst);
  end(*listPosTable*);

{$endif}

procedure ListDFATable;
  var K, State : Integer;
  begin
{$ifdef debug}
    (* list position table: *)
    WriteLn(YYLst);
    WriteLn(YYLst, '( positions : )');
    ListPosTable;
    (* list state table: *)
    WriteLn(YYLst);
    WriteLn(YYLst, '( states : )');
{$endif}
    WriteLn(YYLst);
    for State := 0 to Pred(NStates) do
      begin
        WriteLn(YYLst);
        Write(YYLst, State);
        with StateTable^[State] do
          begin
            if Final then
              Write(YYLst, '* :')
            else
              Write(YYLst, '  :');
{$ifdef debug}
            for K := 1 to Size(StatePos^) do
              Write(YYLst, ' ', StatePos^[K]:5);
{$else}
            for K := 1 to Size(StatePos^) do
              with PosTable^[StatePos^[K]] do
                if (PosType=MarkPos) and (POS=0) then
                  Write(YYLst, ' ', Rule:5);
{$endif}
            WriteLn(YYLst);
            for K := TransLo to TransHi do
              with TransTable^[K] do
                begin
                  ListTrans(CC, NextState);
                  WriteLn(YYLst);
                end;
          end;
      end;
  end(*listDFATable*);

end(*LexList*).
