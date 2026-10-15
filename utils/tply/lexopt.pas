{
  DFA optimization algorithm.
  This is an efficient (O(n log(n)) DFA optimization procedure based on the
  algorithm given in Aho/Sethi/Ullman, 1986, Section 3.9.


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
$Modtime: 96-08-01 6:29 $

$History: LEXOPT.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit LexOpt;

interface



procedure OptimizeDFATable;
  (* optimize the state table *)

implementation

uses LexBase, LexTable;

(* Partition table used in DFA optimization: *)

(* obsolete

const

max_parts = max_states;*)  (* number of partitions of equivalent states; at
                            worst, each state may be in a partition by
                            itself *)

type

TPartTable      = array [0..MaxStates-1] of PIntSet;
                   (* state partitions (DFA optimization) *)

TStatePartTable = array [0..MaxStates-1] of Integer;
                   (* partition number of states *)

var

(* partition table: *)

NParts           : Integer;
PartTable        : ^TPartTable;
StatePart        : ^TStatePartTable;

(* optimized state and transition table: *)

NOptStates      : Integer;
NOptTrans       : Integer;
OptStateTable   : ^TStateTable;
OptTransTable   : ^TTransTable;


function EquivStates(I, J : Integer) : Boolean;
  (* checks whether states i and j are equivalent; two states are considered
     equivalent iff:
     - they cover the same marker positions (/ and endmarkers of rules)
     - they have transitions on the same symbols/characters, and corresponding
       transitions go to states in the same partition
     two different start states are never considered equivalent *)
  var Ii, Jj, K : Integer;
      MarkPosI, MarkPosJ : TIntSet;
  begin
    (* check for start states: *)
    if (I<=2*NStartStates+1) and (J<=2*NStartStates+1) and
       (I<>J) then
      begin
        EquivStates := False;
        Exit;
      end;
    (* check end positions: *)
    Empty(MarkPosI);
    with StateTable^[I] do
      for K := 1 to Size(StatePos^) do
        if PosTable^[StatePos^[K]].PosType=MarkPos then
          Include(MarkPosI, StatePos^[K]);
    Empty(MarkPosJ);
    with StateTable^[J] do
      for K := 1 to Size(StatePos^) do
        if PosTable^[StatePos^[K]].PosType=MarkPos then
          Include(MarkPosJ, StatePos^[K]);
    if not Equal(MarkPosI, MarkPosJ) then
      begin
        EquivStates := False;
        Exit
      end;
    (* check transitions: *)
    if NStateTrans(I)<>NStateTrans(J) then
      EquivStates := False
    else
      begin
        Ii := StateTable^[I].TransLo;
        Jj := StateTable^[J].TransLo;
        for K := 0 to Pred(NStateTrans(I)) do
          if (TransTable^[Ii+K].CC^<>TransTable^[Jj+K].CC^) then
            begin
              EquivStates := False;
              Exit
            end
          else if StatePart^[TransTable^[Ii+K].NextState]<>
                  StatePart^[TransTable^[Jj+K].NextState] then
            begin
              EquivStates := False;
              Exit
            end;
        EquivStates := True;
      end
  end(*equivStates*);

procedure OptimizeDFATable;

  var
    I, Ii, J : Integer;
    ActPart, NewPart, NNewParts : Integer;

  begin

    NParts := 0;

    (* Initially, create one partition containing ALL states: *)

    NParts := 1;
    PartTable^[0] := NewIntSet;
    for I := 0 to NStates-1 do
      begin
        Include(PartTable^[0]^, I);
        StatePart^[I] := 0;
      end;

    (* Now, repeatedly pass over the created partitions, breaking up
       partitions if they contain nonequivalent states, until no more
       partitions have been added during the last pass: *)

    repeat
      NNewParts := 0; ActPart := 0;
      NewPart := NParts;
      PartTable^[NewPart] := NewIntSet;
      while (NParts<NStates) and (ActPart<NParts) do
        begin
          for I := 2 to Size(PartTable^[ActPart]^) do
            if not EquivStates(PartTable^[ActPart]^[1],
                               PartTable^[ActPart]^[I]) then
              (* add to new partition: *)
              Include(PartTable^[NewPart]^, PartTable^[ActPart]^[I]);
          if Size(PartTable^[NewPart]^)<>0 then
            begin
              (* add new partition: *)
              Inc(NParts); Inc(NNewParts);
              (* remove new partition from old one: *)
              SetMinus(PartTable^[ActPart]^, PartTable^[NewPart]^);
              (* update partition assignments: *)
              for I := 1 to Size(PartTable^[NewPart]^) do
                StatePart^[PartTable^[NewPart]^[I]] := NewPart;
              Inc(NewPart);
              PartTable^[NewPart] := NewIntSet;
            end;
          Inc(ActPart);
        end;
    until NNewParts=0;

    (* build the optimized state table: *)

    NOptStates := NParts;
    NOptTrans := 0;
    for I := 0 to NParts-1 do
      begin
        Ii := PartTable^[I]^[1];
        OptStateTable^[I] := StateTable^[Ii];
        with OptStateTable^[I] do
          begin
            TransLo := NOptTrans+1;
            TransHi := NOptTrans+1+StateTable^[Ii].TransHi-
                        StateTable^[Ii].TransLo;
            for J := 2 to Size(PartTable^[I]^) do
              SetUnion(StatePos^, StateTable^[
                                     PartTable^[I]^[J]].StatePos^);
          end;
        for J := StateTable^[Ii].TransLo to StateTable^[Ii].TransHi do
          begin
            Inc(NOptTrans);
            OptTransTable^[NOptTrans] := TransTable^[J];
            with OptTransTable^[NOptTrans] do
              NextState := StatePart^[NextState];
          end;
      end;

      (* update state table: *)

      NStates     := NOptStates;
      NTrans      := NOptTrans;
      StateTable^ := OptStateTable^;
      TransTable^ := OptTransTable^;

  end(*optimizeDFATable*);

begin
  New(PartTable);
  New(StatePart);
  New(OptStateTable);
  New(OptTransTable);
end(*LexOpt*).
