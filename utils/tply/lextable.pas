{
  This module collects the various tables used by the Lex program:
  - the symbol table
  - the position table
  - the DFA states and transition tables
  Note: All tables are allocated dynamically (at initialization time)
  because of the 64KB static data limit.


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
$Modtime: 96-08-01 10:23 $

$History: LEXTABLE.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit LexTable;

interface

uses LexBase;

const

(* Maximum table sizes: *)

MaxKeys           =  997;  (* size of hash symbol table (prime number!)   *)
MaxPos            = 1200;  (* maximum number of positions                 *)
MaxStates         =  600;  (* number of DFA states                        *)
MaxTrans          = 1200;  (* number of transitions                       *)
MaxStartStates   =  100;  (* maximum number of user-defined start states *)

var

(* Actual table sizes: *)

NPos            : Integer;
NStates         : Integer;
NTrans          : Integer;
NStartStates   : Integer;

type

(* Table data structures: *)

TSymTable = array [1..MaxKeys] of record
             Pname  : PStr;
               (* print name; empty entries are denoted by pname=nil *)
             case SymType : ( NoneSym, MacroSym, StartStateSym ) of
             MacroSym : ( Subst : PStr );
               (* macro substitution *)
             StartStateSym : ( StartState : Integer );
               (* start state *)
           end;

TPosTableEntry = record
                  FollowPos    : PIntSet;
                    (* set of follow positions *)
                  case PosType : ( CharPos, CClassPos, MarkPos ) of
                  CharPos      : ( C   : Char );
                    (* character position *)
                  CClassPos    : ( CC  : PCClass );
                    (* character class position *)
                  MarkPos      : ( Rule, POS : Integer );
                    (* mark position *)
                end;

TPosTable = array [1..MaxPos] of TPosTableEntry;

TFirstPosTable  = array [0..2*MaxStartStates+1] of PIntSet;
                   (* first positions for start states (even states
                      are entered anywhere on the line, odd states only
                      at the beginning of the line; states 0 and 1 denote
                      default, states 2..2*n_start_states+1 user-defined
                      start states) *)

TStartStateExclusive = array[0..MaxStartStates] of Boolean;

TStateTableEntry = record
                    StatePos : PIntSet;
                      (* positions covered by state *)
                    Final     : Boolean;
                      (* final state? *)
                    TransLo,
                    TransHi  : Integer;
                      (* transitions *)
                  end;

TStateTable = array [0..MaxStates-1] of TStateTableEntry;

TTransTableEntry = record
                    CC              : PCClass;
                      (* characters of transition *)
                    FollowPos      : PIntSet;
                      (* follow positions (positions of next state) *)
                    NextState      : Integer;
                      (* next state *)
                  end;

TTransTable = array [1..MaxTrans] of TTransTableEntry;


var

Verbose           : Boolean;          (* status of the verbose option *)
Optimize          : Boolean;          (* status of the optimization option *)

SymTable         : ^TSymTable;        (* symbol table *)
PosTable         : ^TPosTable;        (* position table *)
FirstPosTable   : ^TFirstPosTable;   (* first positions table *)
StartExcl        : ^TStartStateExclusive; (* user-defined start state type *)
StateTable       : ^TStateTable;      (* DFA state table *)
TransTable       : ^TTransTable;      (* DFA transition table *)


(* Operations: *)

(* Hash symbol table:
   The following routines are supplied to be used with the generic hash table
   routines in LexBase. *)

function Lookup(K : Integer) : String;
  (* print name of symbol no. k *)
procedure Entry(K : Integer; Symbol : String);
  (* enter symbol into table *)

(* Routines to build the position table: *)

procedure AddCharPos(C : Char);
procedure AddCClassPos(CC : PCClass);
procedure AddMarkPos(Rule, POS : Integer);
  (* Positions are allocated in the order of calls to addCharPos, addCClassPos
     and addMarkPos, starting at position 1. These routines also initialize
     the corresponding follow sets. *)

(* Routines to build the state table: *)

var ActState : Integer; (* state currently considered *)

function NewState(POS : PIntSet) : Integer;
  (* Add a new state with the given position set; initialize the state's
     position set to POS (the offsets into the transition table are
     initialized when the state becomes active, see startStateTrans, below).
     Returns: the new state number *)

function AddState(POS : PIntSet) : Integer;
  (* add a new state, but only if there is not already a state with the
     same position set *)

procedure StartStateTrans;
procedure EndStateTrans;
  (* initializes act_state's first and last offsets into the transition
     table *)

function NStateTrans(I : Integer) : Integer;
  (* return number of transitions in state i *)

procedure AddTrans(CC : TCClass; Follow : PIntSet);
  (* adds a transition to the table *)

procedure MergeTrans;
  (* sorts transitions w.r.t. next states and merges transitions for the
     same next state in the active state *)

procedure SortTrans;
  (* sort transitions in act_state lexicographically *)

implementation

uses LexMsgs;

(* Hash table routines: *)

function Lookup(K : Integer) : String;
  begin
    with SymTable^[K] do
      if Pname=nil then
        Lookup := ''
      else
        Lookup := Copy(Pname^, 1, Length(Pname^))
  end(*lookup*);
procedure Entry(K : Integer; Symbol : String);
  begin
    with SymTable^[K] do
      begin
        Pname    := NewStr(Symbol);
        SymType := NoneSym;
      end
  end(*entry*);

(* Routines to build the position table: *)

procedure AddCharPos(C : Char);
  begin
    Inc(NPos);
    if NPos>MaxPos then Fatal(PosTableOverflow);
    PosTable^[NPos].FollowPos     := NewIntSet;
    PosTable^[NPos].PosType       := CharPos;
    PosTable^[NPos].C              := C;
  end(*addCharPos*);

procedure AddCClassPos(CC : PCClass);
  begin
    Inc(NPos);
    if NPos>MaxPos then Fatal(PosTableOverflow);
    PosTable^[NPos].FollowPos     := NewIntSet;
    PosTable^[NPos].PosType       := CClassPos;
    PosTable^[NPos].CC             := CC;
  end(*addCClassPos*);

procedure AddMarkPos(Rule, POS : Integer);
  begin
    Inc(NPos);
    if NPos>MaxPos then Fatal(PosTableOverflow);
    PosTable^[NPos].FollowPos     := NewIntSet;
    PosTable^[NPos].PosType       := MarkPos;
    PosTable^[NPos].Rule           := Rule;
    PosTable^[NPos].POS            := POS;
  end(*addMarkPos*);

(* Routines to build the state table: *)

function NewState(POS : PIntSet) : Integer;
  begin
    if NStates>=MaxStates then Fatal(StateTableOverflow);
    NewState := NStates;
    with StateTable^[NStates] do
      begin
        StatePos := POS;
        Final     := False;
      end;
    Inc(NStates);
  end(*newState*);

function AddState(POS : PIntSet) : Integer;
  var I : Integer;
  begin
    for I := 0 to Pred(NStates) do
      if Equal(POS^, StateTable^[I].StatePos^) then
        begin
          AddState := I;
          Exit;
        end;
    AddState := NewState(POS);
  end(*addState*);

procedure StartStateTrans;
  begin
    StateTable^[ActState].TransLo := Succ(NTrans);
  end(*startStateTrans*);

procedure EndStateTrans;
  begin
    StateTable^[ActState].TransHi := NTrans;
  end(*endStateTrans*);

function NStateTrans(I : Integer) : Integer;
  begin
    with StateTable^[I] do
      NStateTrans := TransHi-TransLo+1
  end(*n_state_trans*);

(* Construction of the transition table:
   This implementation here uses a simple optimization which tries to avoid
   the construction of different transitions for each individual character
   in large character classes by MERGING transitions whenever possible. The
   transitions, at any time, will be partitioned into transitions on disjoint
   character classes. When adding a new transition on character class cc, we
   repartition the transitions as follows:
   1. If the current character class cc equals an existing one, we can
      simply add the new follow set to the existing one.
   2. Otherwise, for some existing transition on some character class
      cc1 with cc*cc1<>[], we replace the existing transition by a new
      transition on cc*cc1 with follow set = cc1's follow set + cc's follow
      set, and, if necessary (i.e. if cc1-cc is nonempty), a transition on
      cc1-cc with follow set = cc1's follow set. We then remove the elements
      of cc1 from cc, and proceed again with step 1.
   We may stop this process as soon as cc becomes empty (then all characters
   in cc have been distributed among the existing partitions). If cc does
   NOT become empty, we have to construct a new transition for the remaining
   character class (which then will be disjoint from all other character
   classes in the transition table). *)

procedure AddTrans(CC : TCClass; Follow : PIntSet);
  var
    I : Integer;
    CC0, CC1, CC2 : TCClass;
  begin
    for I := StateTable^[ActState].TransLo to NTrans do
      if TransTable^[I].CC^=CC then
        begin
          SetUnion(TransTable^[I].FollowPos^, Follow^);
          Exit
        end
      else
        begin
          CC0 := CC*TransTable^[I].CC^;
          if CC0<>[] then
            begin
              CC1 := TransTable^[I].CC^-CC;
              CC2 := CC-TransTable^[I].CC^;
              if CC1<>[] then
                begin
                  TransTable^[I].CC^ := CC1;
                  Inc(NTrans);
                  if NTrans>MaxTrans then Fatal(TransTableOverflow);
                  TransTable^[NTrans].CC := NewCClass(CC0);
                  TransTable^[NTrans].FollowPos := NewIntSet;
                  TransTable^[NTrans].FollowPos^ :=
                    TransTable^[I].FollowPos^;
                  SetUnion(TransTable^[NTrans].FollowPos^, Follow^);
                end
              else
                begin
                  TransTable^[I].CC^ := CC0;
                  SetUnion(TransTable^[I].FollowPos^, Follow^);
                end;
              CC := CC2;
              if CC=[] then Exit;
            end
        end;
    Inc(NTrans);
    if NTrans>MaxTrans then Fatal(TransTableOverflow);
    TransTable^[NTrans].CC          := NewCClass(CC);
    TransTable^[NTrans].FollowPos  := NewIntSet;
    TransTable^[NTrans].FollowPos^ := Follow^;
  end(*addCharTrans*);

(* comparison and swap procedures for sorting transitions: *)
function TransLessNextState(I, J : Integer) : Boolean;
  (* compare transitions based on next states (used in mergeCharTrans) *)
  begin
    TransLessNextState := TransTable^[I].NextState<
                          TransTable^[J].NextState
  end(*transLessNextState*);
function TransLess(I, J : Integer) : Boolean;
  (* lexical order on transitions *)
  var C : Char; XI, XJ : Boolean;
  begin
    for C := #0 to #255 do
      begin
        XI := C in TransTable^[I].CC^;
        XJ := C in TransTable^[J].CC^;
        if XI<>XJ then
          begin
            TransLess := Ord(XI)>Ord(XJ);
            Exit
          end;
      end;
    TransLess := False
  end(*transLess*);
procedure TransSwap(I, J : Integer);
  (* swap transitions i and j *)
  var X : TTransTableEntry;
  begin
    X := TransTable^[I];
    TransTable^[I] := TransTable^[J];
    TransTable^[J] := X;
  end(*transSwap*);

procedure MergeTrans;
  var
    I, J, NDeleted : Integer;
  begin
    (* sort transitions w.r.t. next states: *)
    QuickSort(StateTable^[ActState].TransLo,
              NTrans,
              {$ifdef fpc}@{$endif}TransLessNextState,
              {$ifdef fpc}@{$endif}TransSwap);
    (* merge transitions for the same next state: *)
    NDeleted := 0;
    for I := StateTable^[ActState].TransLo to NTrans do
    if TransTable^[I].CC<>nil then
      begin
        J := Succ(I);
        while (J<=NTrans) and
              (TransTable^[I].NextState =
               TransTable^[J].NextState) do
          begin
            (* merge cclasses of transitions i and j, then mark
               transition j as deleted *)
            TransTable^[I].CC^ := TransTable^[I].CC^+
                                   TransTable^[J].CC^;
            TransTable^[J].CC  := nil;
            Inc(NDeleted);
            Inc(J);
          end;
      end;
    (* remove deleted transitions: *)
    J := StateTable^[ActState].TransLo;
    for I := StateTable^[ActState].TransLo to NTrans do
      if TransTable^[I].CC<>nil then
        if I<>J then
          begin
            TransTable^[J] := TransTable^[I];
            Inc(J);
          end
        else
          Inc(J);
    (* update transition count: *)
    Dec(NTrans, NDeleted);
  end(*mergeTrans*);

procedure SortTrans;
  begin
    QuickSort(StateTable^[ActState].TransLo,
              NTrans,
              {$ifdef fpc}@{$endif}TransLess,
              {$ifdef fpc}@{$endif}TransSwap);
  end(*sortTrans*);

var I : Integer;

begin

  Verbose          := False;
  Optimize         := False;

  NPos            := 0;
  NStates         := 0;
  NTrans          := 0;
  NStartStates   := 0;

  (* allocate tables: *)

  New(SymTable);
  New(PosTable);
  New(FirstPosTable);
  New(StartExcl);
  New(StateTable);
  New(TransTable);

  (* initialize symbol table: *)

  for I := 1 to MaxKeys do SymTable^[I].Pname := nil;

end(*LexTables*).
