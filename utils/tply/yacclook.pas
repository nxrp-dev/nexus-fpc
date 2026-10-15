{
  Yacc lookahead computation. This implementation is based on the
  lookahead set algorithm described in Aho/Sethi/Ullman, 1986,
  Section 4.7.


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

$History: YACCLOOK.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit YaccLook;

interface


procedure Lookaheads;
  (* computes the LALR lookahead sets and enters corresponding reductions
     into the redn table (sorted w.r.t. rule numbers) *)

implementation

uses YaccBase, YaccTabl;

(* This implementation is based on algorithms 4.12 and 4.13 in Aho/Sethi/
   Ullman 1986 (with some optimizations added), which avoid the need to
   construct the full LR(1) set, and are able to compute lookaheads from
   LR(0) kernel items only.

   We start off with the LR(0) state set together with corresponding (shift
   and goto) transitions already computed. We compute the LALR(1) lookahead
   sets for kernel items and also record all corresponding reduce actions
   in the reduction table (where we also have to consider nonkernel items
   with empty right-hand side; these items also call for a reduction, but
   never appear in the kernel item table).

   This implementation uses some simple optimizations to speed up the
   algorithm. The lookahead sets are represented by (IntSet) pointers.
   Lookahead sets are associated with each kernel item in the item table,
   and with each reduction in the reduction table. A kernel item
   calling for a reduction shares its lookahead set pointer with the
   corresponding entry in the reduction table. The lookahead set for
   a nonkernel reduction item (item with empty right-hand side) only
   appears in the reduction table.

   The algorithm consists of two phases:

   1. Initialization:

      The initialization phase consists of a single traversal of the LR(0)
      set, where we compute lookahead sets generated spontaneously (lookaheads
      which are passed on from nonkernel items to the corresponding items in
      successor states), initialize lookahead sets and enter them into the
      lookahead and reduction table. Furthermore, during the initialization
      phase we also initialize the links for the propagation of lookaheads
      in the second phase.

      To determine lookaheads and propagation links, we compute the look-
      aheads for the closures of single LR(0) sets "in the small", according
      to the method in Aho/Sethi/Ullman 1986 (with some modifications),
      where we associate with each kernel item i a corresponding endmarker
      symbol #i as its lookahead symbol.

      The initialization phase proceeds as follows:

      1) Initialize all nonkernel item lookahead sets to empty.

      Now we pass over each state s in the LR0 set, repeating steps 2) thru
      5) specified below:

      2) Compute the closure closure(K(s)) of the states's kernel set K(s).

      3) Compute the lookahead sets for closure(K(s)) (described in detail
         below) where each kernel item i is associated with a special
         endmarker symbol #i as lookahead.

      Now the lookahead symbols, reductions and propagation links are entered
      into the corresponding tables as follows:

      4) Process kernel items: Add a propagation link from the kernel item
         to the lookahead set of the linked item in the corresponding
         successor state (as specified by the next field). If there is no
         successor item (kernel item calling for a reduction), add a
         corresponding entry into the reduction table instead.

      5) Process nonkernel items: find the corresponding kernel item in the
         successor state which is generated spontaneously from the nonkernel
         item. Add the spontaneous lookahead symbols (except endmarker
         symbols) of the nonkernel item determined in step 3) to the kernel
         item. If the nonkernel item has an empty right-hand side (nonkernel
         item calling for a reduction), add a corresponding entry into the
         reduction table instead. Furthermore, for each endmarker symbol
         #i in the spontaneous lookahead set of the nonkernel item, add
         a corresponding propagation link from the ith kernel item to the
         lookahead set of the spontaneous kernel item.

      To compute the spontaneous lookaheads (step 3)), we proceed as follows:

      3a) First compute the first sets of tail strings of all items in
          closure(K(s)). The "tail string" of an item [ X -> v.Yw ], where
          Y is a nonterminal, is the symbol sequence w, whose first set
          induces corresponding spontaneous lookaheads in the nonkernel
          items of the state with left-hand side Y; note that the first
          sets of "tail strings" in items [ X -> v.yw ], where y is a
          *terminal* symbol, are not required and hence it is not
          necessary to compute them. We also record for each item whether
          its tail string is "nullable", i.e., may be derived to the empty
          string. In this case, the item also passes on its own lookaheads,
          in addition to the first symbols of its tail string. First sets
          and nullable flags are computed using the information in YaccTable's
          first and nullable tables.

      3b) Now follows an initialization part in which each item [ X -> v.Yw ]
          passes on the first symbols of its tail string to the lookahead
          sets of each corresponding nonkernel item [ Y -> .u ].

      3c) Finally, we repeatedly pass over the item set, passing on
          lookaheads from items with nullable tail strings. Each item
          [ X -> v.Yw ] with nullable w propagates its own lookaheads to
          all corresponding nonkernel items [ Y -> .u]. Step 3c) terminates
          as soon as no lookahead sets have been modified during the previous
          pass.

   2. Propagation:

      The second phase of the lookahead computation algorithm now is quite
      simple. We repeatedly pass over all kernel items, propagating lookaheads
      according to the propagation links determined in the initialization
      phase. The algorithm terminates as soon as no lookahead sets have been
      modified during the previous pass. *)

(* Data structures used in lookahead computation: *)

type

TSymSetArray = array [1..MaxSetItems] of TIntSet;
TBoolArray   = array [1..MaxSetItems] of Boolean;

var

ItemSet       : TItemSet;
LookaheadSet  : TSymSetArray;
NKernelItems : Integer;

procedure SpontaneousLookaheads;

  (* compute spontaneous lookaheads for item_set; negative symbols are
     used for endmarkers (-i denotes endmarker #i) *)

  var Count, LastCount, I : Integer;
      FirstSyms : TSymSetArray;
      Nullable : TBoolArray;

  function SymCount ( N : Integer ) : Integer;
    (* count lookahead symbols *)
    var Count, I : Integer;
    begin
      Count := 0;
      for I := 1 to N do
        Inc(Count, Size(LookaheadSet[I]));
      SymCount := Count;
    end(*sym_count*);

  procedure ComputeFirstSyms ( I : Integer );
    (* compute first set and nullable flag for tail string of item
       number i *)
    var J : Integer;
    begin
      Empty(FirstSyms[I]); Nullable[I] := True;
      with ItemSet, Item[I], RuleTable^[RuleNo]^ do
        if (PosNo<=RHSLen) and (RHSSym[PosNo]<0) then
          begin
            J := PosNo+1;
            while (J<=RHSLen) and Nullable[I] do
              begin
                if RHSSym[J]<0 then
                  begin
                    SetUnion(FirstSyms[I], FirstSetTable^[-RHSSym[J]]^);
                    Nullable[I] := YaccTabl.Nullable^[-RHSSym[J]];
                  end
                else
                  begin
                    Include(FirstSyms[I], RHSSym[J]);
                    Nullable[I] := False;
                  end;
                Inc(J);
              end;
          end;
    end(*compute_first_syms*);

  procedure InitLookaheads ( I : Integer );
    (* compute initial lookaheads induced by first sets of tail string
       of item i *)
    var Sym, J : Integer;
    begin
      with ItemSet, Item[I], RuleTable^[RuleNo]^ do
        if (PosNo<=RHSLen) and (RHSSym[PosNo]<0) then
          begin
            Sym := RHSSym[PosNo];
            for J := NKernelItems+1 to NItems do
              with Item[J], RuleTable^[RuleNo]^ do
                if LHSSym=Sym then
                  SetUnion(LookaheadSet[J], FirstSyms[I]);
          end
    end(*initial_lookaheads*);

  procedure Propagate ( I : Integer );
    (* propagate lookahead symbols of item i *)
    var Sym, J : Integer;
    begin
      with ItemSet, Item[I], RuleTable^[RuleNo]^ do
        if (PosNo<=RHSLen) and (RHSSym[PosNo]<0) and Nullable[I] then
          begin
            Sym := RHSSym[PosNo];
            for J := NKernelItems+1 to NItems do
              with Item[J], RuleTable^[RuleNo]^ do
                if LHSSym=Sym then
                  SetUnion(LookaheadSet[J], LookaheadSet[I]);
          end
    end(*propagate*);

  begin(*spontaneous_lookaheads*)
    with ItemSet do
      begin
        (* initialize kernel lookahead sets: *)
        for I := 1 to NKernelItems do Singleton(LookaheadSet[I], -I);
        (* compute first sets and nullable flags: *)
        for I := 1 to NItems do ComputeFirstSyms(I);
        (* initialize nonkernel lookahead sets: *)
        for I := NKernelItems+1 to NItems do Empty(LookaheadSet[I]);
        for I := 1 to NItems do InitLookaheads(I);
        (* repeated passes until no more lookaheads have been added
           during the previous pass: *)
        Count := SymCount(NItems);
        repeat
          LastCount := Count;
          for I := 1 to NItems do
            Propagate(I);
          Count := SymCount(NItems);
        until LastCount=Count;
      end;
  end(*spontaneous_lookaheads*);

function RednsLess ( I, J : Integer ) : Boolean;
  begin
    RednsLess := RednTable^[I].RuleNo<RednTable^[J].RuleNo
  end(*redns_less*);

procedure RednsSwap ( I, J : Integer );
  var X : TRednRec;
  begin
    X := RednTable^[I];
    RednTable^[I] := RednTable^[J];
    RednTable^[J] := X;
  end(*redns_swap*);

procedure SortRedns;
  (* sort reduction entries in act_state w.r.t. rule numbers *)
  begin
    with StateTable^[ActState] do
      QuickSort(RednsLo, RednsHi, {$ifdef fpc}@{$endif}RednsLess,
                {$ifdef fpc}@{$endif}RednsSwap);
  end(*sort_redns*);

procedure Initialize;

  (* initialization phase of lookahead computation algorithm *)

  procedure AddProp ( I : Integer; SymSet : PIntSet );
    (* add a propagation link to kernel item i *)
    var Prop : PPropList;
    begin
      New(Prop);
      Prop^.SymSet := SymSet;
      Prop^.Next := PropTable^[I];
      PropTable^[I] := Prop;
    end(*add_prop*);

  var I, J, K : Integer;
      Lookaheads : PIntSet;

  begin
    (* initialize lookahead sets and propagation links: *)
    for I := 1 to NItems do LookaheadTable^[I] := NewEmptyIntSet;
    for I := 1 to NItems do PropTable^[I] := nil;
    ActState := 0;
    repeat
      with StateTable^[ActState], ItemSet do
        begin
          StartRedns;
          GetItemSet(ActState, ItemSet);
          NKernelItems := NItems;
          (* compute LR(0) closure: *)
          Closure(ItemSet);
          (* compute spontaneous lookaheads: *)
          SpontaneousLookaheads;
          (* process kernel items: *)
          for I := 1 to NKernelItems do with Item[I] do
            if Next>0 then
              (* add propagation link: *)
              AddProp(ItemLo+I-1, LookaheadTable^[Next])
            else
              (* enter reduce action: *)
              AddRedn(LookaheadTable^[ItemLo+I-1], RuleNo);
          (* process nonkernel items: *)
          (* find successor items: *)
          for K := TransLo to TransHi do
            with TransTable^[K] do
              for I := NKernelItems+1 to NItems do
                with Item[I], RuleTable^[RuleNo]^ do
                  if PosNo>RHSLen then
                    Next := 0
                  else if RHSSym[PosNo]=Sym then
                    Next := FindItem(NextState, RuleNo, PosNo+1);
          (* add spontaneous lookaheads and propagation links: *)
          for I := NKernelItems+1 to NItems do with Item[I] do
            if Next>0 then
              (* lookaheads are generated spontaneously for successor
                 item: *)
              for J := 1 to Size(LookaheadSet[I]) do
                if LookaheadSet[I][J]>=0 then
                  Include(LookaheadTable^[Next]^, LookaheadSet[I][J])
                else
                  AddProp(ItemLo+(-LookaheadSet[I][J])-1,
                           LookaheadTable^[Next])
            else
              (* nonkernel reduction item: *)
              begin
                Lookaheads := NewEmptyIntSet;
                for J := 1 to Size(LookaheadSet[I]) do
                  if LookaheadSet[I][J]>=0 then
                    Include(Lookaheads^, LookaheadSet[I][J])
                  else
                    AddProp(ItemLo+(-LookaheadSet[I][J])-1,
                             Lookaheads);
                AddRedn(Lookaheads, RuleNo);
              end;
          EndRedns;
          SortRedns;
        end;
      Inc(ActState);
    until ActState=NStates;
  end(*initialize*);

procedure Propagate;

  (* propagation phase of lookahead computation algorithm *)

  var I, L : Integer;
      Done : Boolean;
      Prop : PPropList;

  begin
    (* repeated passes over the kernel items table until no more lookaheads
       could be added in the previous pass: *)
    repeat
      Done := True;
      for I := 1 to NItems do
        begin
          Prop := PropTable^[I];
          while Prop<>nil do with Prop^ do
            begin
              L := Size(SymSet^);
              SetUnion(SymSet^, LookaheadTable^[I]^);
              if Size(SymSet^)>L then Done := False;
              Prop := Next;
            end;
        end;
    until Done;
  end(*propagate*);

procedure Lookaheads;
  begin
    Initialize;
    Propagate;
  end(*lookaheads*);

end(*YaccLookaheads*).
