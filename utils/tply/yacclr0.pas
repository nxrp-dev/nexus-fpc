{
  LR(0) set construction. For an explanation of this algorithm, see
  Aho/Sethi/Ullman, "Compilers : Principles, Techniques and Tools,"
  1986, Section 4.7.


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
$Modtime: 96-07-31 14:09 $

$History: YACCLR0.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit YaccLR0;

interface


procedure LR0Set;
  (* constructs the LR(0) state set, shift and goto transitions and
     corresponding kernel items *)

implementation

uses YaccBase, YaccTabl;

(* This implementation is based on the algorithm given in Aho/Sethi/Ullman,
   1986, Section 4.7. *)

procedure GetSyms ( var ItemSet : TItemSet; var SymbolSet : TIntSet );
  (* get the symbols for which there are transitions in item_set *)
  var I : Integer;
  begin
    with ItemSet do
      begin
        Empty(SymbolSet);
        for I := 1 to NItems do
          with Item[I], RuleTable^[RuleNo]^ do
            if PosNo<=RHSLen then
              Include(SymbolSet, RHSSym[PosNo]);
      end;
  end(*get_syms*);

function MakeState ( var ItemSet : TItemSet; Sym : Integer ) : Integer;
  (* construct a new state for the transitions in item_set on symbol sym;
     returns: the new state number *)
  var I : Integer;
  begin
    with ItemSet do
      begin
        (* add the new state: *)
        NewState;
        for I := 1 to NItems do
          with Item[I], RuleTable^[RuleNo]^ do
            if (PosNo<=RHSLen) and (RHSSym[PosNo]=Sym) then
              AddItem(RuleNo, PosNo+1);
        MakeState := AddState;
      end;
  end(*make_state*);

procedure AddNextLinks;
  (* add links to successor items for kernel items in the active state *)
  var K, I : Integer;
  begin
    with StateTable^[ActState] do
      for K := TransLo to TransHi do
        with TransTable^[K] do
          for I := ItemLo to ItemHi do
            with ItemTable^[I], RuleTable^[RuleNo]^ do
              if (PosNo<=RHSLen) and (RHSSym[PosNo]=Sym) then
                Next := FindItem(NextState, RuleNo, PosNo+1 );
  end(*add_next_links*);

procedure LR0Set;
  var ActItems : TItemSet;
      ActSyms  : TIntSet;
      I         : Integer;
  begin
    (* initialize state 0: *)
    NewState;
    AddItem(1, 1);  (* augmented start production *)
    ActState := AddState;
    (* build the state table: *)
    repeat
      (* compute the closure of the current state: *)
      GetItemSet(ActState, ActItems);
      Closure(ActItems);
      (* sort items: *)
      SortItemSet(ActItems);
      (* determine symbols used in shift and goto transitions: *)
      GetSyms(ActItems, ActSyms);
      (* add transitions: *)
      StartTrans;
      for I := 1 to Size(ActSyms) do
        if ActSyms[I]=0 then
          (* accept action *)
          AddTrans(0, 0)
        else
          (* shift/goto action *)
          AddTrans(ActSyms[I], MakeState(ActItems, ActSyms[I]));
      EndTrans;
      (* add next links to kernel items: *)
      AddNextLinks;
      (* switch to next state: *)
      Inc(ActState);
    until ActState=NStates;
  end(*LR0Set*);

end(*YaccLR0*).
