{
  Yacc closure and first set construction algorithms. See Aho/Sethi/Ullman,
  1986, Sections 4.4 and 4.7, for further explanation.


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

$History: YACCCLOS.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit YaccClos;

interface


procedure Closures;
  (* compute the closure sets *)

procedure FirstSets;
  (* compute first sets and nullable flags *)

implementation

uses YaccBase, YaccTabl;

procedure Closures;

  (* The closure set of a nonterminal X is the set of all nonterminals Y
     s.t. Y appears as the first symbol in a rightmost derivation from the
     nonterminal X (i.e. X =>+ Y ... in a rightmost derivation). We can
     easily compute closure sets as follows:
     - Initialize the closure set for any nonterminal X to contain all
       nonterminals Y for which there is a rule X : Y ...
     - Now repeatedly pass over the already constructed sets, and for
       any nonterminal Y which has already been added to the closure set
       of some nonterminal X, also include the closure elements of Y in
       the closure set of X.
     The algorithm terminates as soon as no additional symbols have been
     added during the previous pass. *)

  var Sym, I, Count, PrevCount : Integer;
      ActSyms : TIntSet;

  begin
    (* initialize closure sets: *)
    PrevCount := 0;
    Count := 0;
    for Sym := 1 to NNTs do
      begin
        ClosureTable^[Sym] := NewEmptyIntSet;
        with RuleOffs^[Sym] do
          for I := RuleLo to RuleHi do
            with RuleTable^[RuleNo^[I]]^ do
              if (RHSLen>0) and (RHSSym[1]<0) then
                Include(ClosureTable^[Sym]^, RHSSym[1]);
        Inc(Count, Size(ClosureTable^[Sym]^));
      end;
    (* repeated passes until no more symbols have been added during the last
       pass: *)
    while PrevCount<Count do
      begin
        PrevCount := Count;
        Count := 0;
        for Sym := 1 to NNTs do
          begin
            ActSyms := ClosureTable^[Sym]^;
            for I := 1 to Size(ActSyms) do
              SetUnion(ClosureTable^[Sym]^, ClosureTable^[-ActSyms[I]]^);
            Inc(Count, Size(ClosureTable^[Sym]^));
          end;
      end;
  end(*closures*);

procedure FirstSets;

  (* The first set of a nonterminal X is the set of all literal symbols
     y s.t. X =>+ y ... in some derivation of the nonterminal X. In
     addition, X is nullable if the empty string can be derived from X.
     Using the first set construction algorithm of Aho/Sethi/Ullman,
     Section 4.4, the first sets and nullable flags are computed as
     follows:

     For any production X -> y1 ... yn, where the yi are grammar symbols,
     add the symbols in the first set of y1 (y1 itself if it is a literal)
     to the first set of X; if y1 is a nullable nonterminal, then proceed
     with y2, etc., until either all yi have been considered or yi is non-
     nullable (or a literal symbol). If all of the yi are nullable (in
     particular, if n=0), then also set nullable[X] to true.

     This procedure is repeated until no more symbols have been added to any
     first set and none of the nullable flags have been changed during the
     previous pass. *)

  var I, J, L, Sym : Integer;
      N, Null, Done : Boolean;

  begin
    (* initialize tables: *)
    for Sym := 1 to NNTs do
      begin
        Nullable^[Sym] := False;
        FirstSetTable^[Sym] := NewEmptyIntSet;
      end;
    (* repeated passes until no more symbols added and no nullable flags
       modified: *)
    repeat
      Done := True;
      for I := 1 to NRules do
        with RuleTable^[I]^ do
          begin
            L := Size(FirstSetTable^[-LHSSym]^);
            N := Nullable^[-LHSSym];
            Null := True;
            J := 1;
            while (J<=RHSLen) and Null do
              begin
                if RHSSym[J]<0 then
                  begin
                    SetUnion( FirstSetTable^[-LHSSym]^,
                              FirstSetTable^[-RHSSym[J]]^ );
                    Null := Nullable^[-RHSSym[J]];
                  end
                else
                  begin
                    Include( FirstSetTable^[-LHSSym]^,
                             RHSSym[J] );
                    Null := False;
                  end;
                Inc(J);
              end;
            if Null then Nullable^[-LHSSym] := True;
            if (L<Size(FirstSetTable^[-LHSSym]^)) or
               (N<>Nullable^[-LHSSym]) then
              Done := False;
          end;
    until Done;
  end(*first_sets*);

end(*YaccClosure*).

