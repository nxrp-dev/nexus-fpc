{
  DFA table construction. This code, admittedly, is not the most aesthetic,
  but it's quite efficient (and that's the main goal). For further
  explanation, refer to Aho/Sethi/Ullman 1986, Section 3.9.


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
$Modtime: 96-08-01 6:13 $

$History: LEXDFA.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit LexDFA;

interface



procedure MakeDFATable;
  (* construct DFA from position table *)

implementation

uses LexBase, LexTable;

procedure MakeDFATable;
  var I : Integer;
  begin
    (* initialize start states: *)
    for I := 2 to 2*NStartStates+1 do
      if not StartExcl^[I div 2] then
        SetUnion(FirstPosTable^[I]^, FirstPosTable^[I mod 2]^);
    for I := 0 to 2*NStartStates+1 do
      ActState := NewState(FirstPosTable^[I]);
    ActState := -1;
    while Succ(ActState)<NStates do
      begin
        Inc(ActState);
        (* add transitions for active state: *)
        StartStateTrans;
        for I := 1 to Size(StateTable^[ActState].StatePos^) do
          with PosTable^[StateTable^[ActState].StatePos^[I]] do
            if PosType=CharPos then
              AddTrans([C], FollowPos)
            else if PosType=CClassPos then
              AddTrans(CC^, FollowPos)
            else if POS=0 then
              StateTable^[ActState].Final := True;
        (* assign next states: *)
        for I := StateTable^[ActState].TransLo to NTrans do
          with TransTable^[I] do
            NextState := AddState(FollowPos);
        (* merge transitions for the same next state: *)
        MergeTrans;
        (* sort transitions: *)
        SortTrans;
        EndStateTrans;
      end;
  end(*makeDFATable*);

end(*LexDFA*).
