{
  This module collects the various tables used by the Yacc program:
  - the symbol table
  - the rule table
  - the precedence table
  - the closure table
  - the LALR state, item, transition and reduction table
  Note: All tables are allocated dynamically (at initialization time)
  because of the 64KB static data limit. *)


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
$Modtime: 96-07-31 21:15 $

$History: YACCTABL.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit YaccTabl;

interface

uses
  YaccBase;


const

(* Maximum table sizes: *)

MaxKeys           =  997;  (* size of hash symbol table (prime number!)   *)
MaxNTs            =  900;  (* maximum number of nonterminals              *)
MaxLits           =  MaxNTs+256;  (* number of literals (300+256)                *)
MaxRules          =  MaxNTs+1;  (* number of rules (300+1)                     *)
MaxTypes          =  100;  (* number of type tags                         *)
MaxPrec           =   50;  (* maximum precedence level                    *)
{$IFDEF Windows}
MaxStates         = 3000;  (* number of LR(0) states                      *)
{$ELSE}
MaxStates         = 3000;  (* number of LR(0) states                      *)
{$ENDIF}
MaxItems          = 40000;  (* number of items                             *)
MaxTrans          = 40000;  (* number of transitions                       *)
MaxRedns          =  9600;  (* number of reductions                        *)

MaxRuleLen       =   64;  (* maximum length of rules                     *)
MaxSetItems      = 9600;  (* maximum number of items in an item set      *)

var

(* Actual table sizes: *)

NNTs            : Integer;
NLits           : Integer;
NRules          : Integer;
NTypes          : Integer;
NPrec           : Integer;
NStates         : Integer;
NItems          : Integer;
NTrans          : Integer;
NRedns          : Integer;

type

(* Table data structures: *)

(* Symbol table: The symbol table consists of a hash table which stores
   print names and internal symbol numbers, and a key table which stores,
   for each internal symbol number, the corresponding hash key. *)

TSymRec = record
           Pname  : PStr;
             (* print name; empty entries are denoted by pname=nil *)
           Deff   : Boolean;
             (* flag denoting whether symbol is already defined *)
           Sym    : Integer;
             (* internal symbol number (0 or positive: literal symbols
                (literal characters have symbol numbers 1 thru 255);
                negative: nonterminal symbols; 0 denotes endmarker,
                -1 augmented start nonterminal, 256 is reserved for
                error token; note that the predefined symbols except
                the error literal are not actually stored in the symbol
                table; the error symbol is entered at initialization
                s.t. it always has number 256) *)
         end;

TSymTable = array [1..MaxKeys] of TSymRec;

TSymKeyTable = array [-MaxNTs..MaxLits-1] of Integer;
  (* hash keys for nonterminal and literal symbols *)

(* Rule table: the rule table consists of an array storing the rules
   sequentially in the order in which they appear in the source grammar;
   a rule no.s table which is used to sort rules w.r.t. left-hand side
   nonterminals (after the rule table has been constructed and sorted, all
   references to rules are done indirectly via the rule_no array s.t. the
   rules for each nonterminal can be accessed easily); and an offset table
   which stores, for each nonterminal, the corresponding first and last
   index in the rule no.s table. *)

TRuleRec = record
            LHSSym : Integer; (* lhs nonterminal *)
            RHSLen : Integer; (* length of rhs *)
            RHSSym : array [1..MaxRuleLen] of Integer;
              (* rhs symbols *)
          end;

PRuleRec = ^TRuleRec;

TRuleTable = array [1..MaxRules] of PRuleRec;

TRuleNoTable = array [1..MaxRules] of Integer;

TRuleOffsRec = record
                RuleLo, RuleHi : Integer;
              end;

TRuleOffsTable = array [1..MaxNTs] of TRuleOffsRec;

(* Symbol type table: The symbol type table stores the types associated
   with the nonterminal and terminal grammar symbols (0 if none). *)

TTypeTable    = array [1..MaxTypes] of Integer;
  (* types declared in the definitions section *)

TSymTypeTable = array [-MaxNTs..MaxLits-1] of Integer;
  (* symbol types *)

(* Precedence table: The precedence table stores the type of each
   precedence level (left, right, nonassoc) and, for each literal
   symbol and grammar rule, the assigned precedence level (precedence
   level 0 if none). *)

TPrecType = ( Left, Right, NonAssoc );

TPrecTable = array [1..MaxPrec] of TPrecType;

TSymPrecTable = array [0..MaxLits-1] of Integer;

TRulePrecTable = array [1..MaxRules] of Integer;

(* Closure and first symbols table: The closure table stores, for each
   nonterminal X, the set of those nonterminals Y for which there is a
   rightmost derivation X =>+ Y ... . Similarly, the first set table
   stores, for each nonterminal X, the set of literals a for which there
   is a derivation X =>+ a ... . Both tables are of type SymSetTable.

   The nullable table stores, for each nonterminal, a flag denoting whether
   the nonterminal is nullable (i.e. may be derived to the empty string).

   These tables are constructed by the routines in the YaccClosure unit,
   and are used by the LALR parser construction algorithms in YaccLR0 and
   YaccLookaheads. *)

TSymSetTable = array [1..MaxNTs] of PIntSet;

TNullableTable = array [1..MaxNTs] of Boolean;

(* State table:

   Each state stores the first and last index of the kernel items,
   transitions and reductions belonging to it, and a hash key determined
   from the kernel items which is used to speed up searches for existing
   states.

   The items table stores the individual kernel items in the LR(0) set.
   Each entry consists of a rule number together with the item position,
   and a "next" field indicating the associated item in the successor state
   (0 if there is none). The ItemSet type is used to retrieve and manipulate
   individual item sets from the item table.

   The transition table stores the shift and goto transitions in each state
   (each transition is denoted by a (symbol, next_state) pair). Similarly,
   the reductions table stores the reductions in each state, where each
   action is denoted by a (symbolset, ruleno) pair. *)

TStateRec = record
             ItemLo, ItemHi : Integer;
             TransLo, TransHi : Integer;
             RednsLo, RednsHi : Integer;
             Key : Integer;
           end;

TStateTable = array [0..MaxStates-1] of TStateRec;

TItemRec = record
            RuleNo, PosNo : Integer;
            Next : Integer;
          end;

TItemSet = record
            NItems : Integer;
            Item    : array [1..MaxSetItems] of TItemRec;
          end;

TItemTable = array [1..MaxItems] of TItemRec;

TTransRec = record
             Sym, NextState : Integer;
           end;

TTransTable = array [1..MaxTrans] of TTransRec;

TRednRec = record
            SymSet : PIntSet;
            RuleNo : Integer;
          end;

TRednTable = array [1..MaxRedns] of TRednRec;

(* Lookaheads table: This table stores, for each kernel item, the
   corresponding LALR(1) lookahead symbol sets. *)

TLookaheadTable = array [1..MaxItems] of PIntSet;

(* The propagation table is used to keep track of how lookaheads are
   propagated from kernel items to other lookahead sets. *)

PPropList = ^TPropEntry;

TPropEntry = record
              SymSet : PIntSet;
              Next : PPropList;
            end;

TPropTable = array [1..MaxItems] of PPropList;


var

Verbose           : Boolean;          (* status of the verbose option *)
Debug             : Boolean;          (* status of the debug option *)
StartNT           : Integer;          (* start nonterminal of grammar
                                         (0 if undefined) *)
SymTable         : ^TSymTable;        (* symbol table *)
SymKey           : ^TSymKeyTable;     (* symbol keys *)
RuleTable        : ^TRuleTable;       (* rule table *)
TypeTable        : ^TTypeTable;       (* type table *)
SymType          : ^TSymTypeTable;    (* symbol types *)
PrecTable        : ^TPrecTable;       (* precedence table *)
SymPrec          : ^TSymPrecTable;    (* literal symbols precedence *)
RulePrec         : ^TRulePrecTable;   (* rules precedence *)
RuleNo           : ^TRuleNoTable;     (* rule no table *)
RuleOffs         : ^TRuleOffsTable;   (* rule offset table *)
ClosureTable     : ^TSymSetTable;     (* closure table *)
FirstSetTable   : ^TSymSetTable;     (* first set table *)
Nullable          : ^TNullableTable;   (* nullable flags table *)
StateTable       : ^TStateTable;      (* LR(0) state table *)
ItemTable        : ^TItemTable;       (* LR(0) kernel item table *)
TransTable       : ^TTransTable;      (* transition table *)
RednTable        : ^TRednTable;       (* reduction table *)
LookaheadTable   : ^TLookaheadTable;  (* LALR lookaheads table *)
PropTable        : ^TPropTable;       (* lookahead propagation table *)


(* Operations: *)

(* Symbol table routines: *)

function NewNT : Integer;
  (* returns a new nonterminal number (<-1) *)

function NewLit : Integer;
  (* returns a new literal number above 256 *)

procedure AddLit ( Sym : Integer );
  (* this routine allows to add a user-defined literal symbol;
     the current literal symbols count is adjusted accordingly *)

function GetKey ( Symbol : String ) : Integer;
  (* returns a hash key for symbol *)

procedure DefKey ( K : Integer; Sym : Integer );
  (* defines k to be a new symbol with internal symbol number sym *)

function IsDefKey ( K : Integer; var Sym : Integer ) : Boolean;
  (* checks whether symbol denoted by symbol table key k is already
     defined; if so, returns the corresponding symbol number *)

function Pname ( Sym : Integer ) : String;
  (* returns the print name of an internal symbol (`$end' for
     symbol 0, `$accept' for nonterminal -1, and a single quoted
     character for literals 1..255) *)

(* Rule table routines: *)

function NewRuleRec ( R : TRuleRec ) : PRuleRec;
  (* obtains a dynamic copy of r (only the number of bytes actually
     needed is allocated) *)

procedure AddRule ( R : PRuleRec );
  (* add a rule to the rule table *)

procedure SortRules;
  (* sorts rules w.r.t. left-hand sides into the rule no table *)

procedure RuleOffsets;
  (* computes rule offsets after rules have been sorted *)

function NNTRules ( Sym : Integer ) : Integer;
  (* returns number of rules for nonterminal sym *)

(* Type Table routines: *)

procedure AddType ( K : Integer );
  (* add a type identifier to the table *)

procedure SortTypes;
  (* sort the type table alphabetically, eliminate dups *)

function SearchType ( Symbol : String ) : Boolean;
  (* search the sorted types table for the given type symbol *)

(* Precedence table routines: *)

function NewPrecLevel ( PrecType : TPrecType ) : Integer;
  (* adds a new precedence level of the denoted type; returns: the new
     level *)

(* State table routines: *)

var ActState : Integer; (* state currently considered *)

procedure NewState;
  (* build a new state *)

procedure AddItem ( RuleNo, PosNo : Integer );
  (* add an item to the new state (initialize its next field to 0) *)

function AddState : Integer;
  (* add the new state to the state table; if an equivalent state is already
     in the table, dispose the new state, and return the existing state
     number, otherwise return the new state number *)

procedure StartTrans;
  (* starts building transitions of the active state *)

procedure AddTrans ( Sym, NextState : Integer );
  (* adds a transition to the active state *)

procedure EndTrans;
  (* ends transitions of the active state *)

procedure StartRedns;
  (* starts building reduction actions of the active state *)

procedure AddRedn ( SymSet : PIntSet; RuleNo : Integer );
  (* adds a reduction to the active state *)

procedure EndRedns;
  (* ends reduction actions of the active state *)

function NStateItems ( S : Integer ) : Integer;
function NStateTrans ( S : Integer ) : Integer;
function NStateRedns ( S : Integer ) : Integer;
  (* return the number of kernel items, transitions and reductions in state
     s, respectively *)

function FindItem( S : Integer; RuleNo, PosNo : Integer ) : Integer;
  (* find item (rule_no, pos_no) in state s; returns: the item number *)

(* Item set routines: *)

procedure EmptyItemSet ( var ItemSet : TItemSet );
  (* initializes an empty item set *)

procedure IncludeItemSet ( var ItemSet : TItemSet;
                             RuleNo, PosNo : Integer);
  (* add the denoted item to the given item set *)

procedure GetItemSet ( S : Integer; var ItemSet : TItemSet);
  (* obtain the item set of state s from the item table *)

procedure Closure ( var ItemSet : TItemSet );
  (* compute the closure of item_set (using the closure table) *)

procedure SortItemSet ( var ItemSet : TItemSet );
  (* sorts an item set w.r.t. position and rule numbers (higher positions,
     lower rules first) *)

implementation

uses YaccMsgs;

(* Symbol table routines: *)

function NewNT : Integer;
  begin
    Inc(NNTs);
    if NNTs>MaxNTs then Fatal(NTTableOverflow);
    SymType^[-NNTs] := 0;
    NewNT := -NNTs;
  end(*new_nt*);

function NewLit : Integer;
  begin
    Inc(NLits);
    if NLits>MaxLits then Fatal(LitTableOverflow);
    SymType^[NLits-1] := 0;
    SymPrec^[NLits-1] := 0;
    NewLit := NLits-1;
  end(*new_lit*);

procedure AddLit ( Sym : Integer );
  begin
    if Sym>NLits then NLits := Sym;
    if NLits>MaxLits then Fatal(LitTableOverflow);
    SymType^[Sym] := 0;
    SymPrec^[Sym] := 0;
  end(*add_lit*);

function Lookup(K : Integer) : String;
  (* print name of symbol no. k *)
  begin
    with SymTable^[K] do
      if Pname=nil then
        Lookup := ''
      else
        Lookup := Pname^
  end(*lookup*);

procedure Entry(K : Integer; Symbol : String);
  (* enter symbol into table *)
  begin
    SymTable^[K].Pname := NewStr(Symbol);
  end(*entry*);

function GetKey ( Symbol : String ) : Integer;
  begin
    GetKey := Key(Symbol, MaxKeys, {$ifdef fpc}@{$endif}Lookup,
                   {$ifdef fpc}@{$endif}Entry);
  end(*get_key*);

procedure DefKey ( K : Integer; Sym : Integer );
  begin
    SymKey^[Sym] := K;
    SymTable^[K].Deff := True;
    SymTable^[K].Sym  := Sym;
  end(*def_key*);

function IsDefKey ( K : Integer; var Sym : Integer ) : Boolean;
  begin
    if SymTable^[K].Deff then
      begin
        Sym := SymTable^[K].Sym;
        IsDefKey := True;
      end
    else
      IsDefKey := False
  end(*is_def_key*);

function Pname ( Sym : Integer ) : String;
begin
  case Sym of
    1..255 : Pname := SingleQuoteStr(Chr(Sym));
    0      : Pname := '$end';
    -1     : Pname := '$accept';
  else  begin
    if SymTable^[SymKey^[Sym]].Pname^[1]=''''
      then  begin
        Pname := SingleQuoteStr(
                   Copy( SymTable^[SymKey^[Sym]].Pname^,
                         2,
                         Length(SymTable^[SymKey^[Sym]].Pname^)-2)
                 )
      end
      else  begin
        Pname := SymTable^[SymKey^[Sym]].Pname^;
      end;
  end;
  end;
end(*pname*);

(* Rule table: *)

function NewRuleRec ( R : TRuleRec ) : PRuleRec;
  var RP : PRuleRec;
  begin
    GetMem(RP, 2*SizeOf(Integer)+R.RHSLen*SizeOf(Integer));
    Move(R, RP^, 2*SizeOf(Integer)+R.RHSLen*SizeOf(Integer));
    NewRuleRec := RP;
  end(*newRuleRec*);

procedure AddRule ( R : PRuleRec );
  begin
    Inc(NRules);
    if NRules>MaxRules then Fatal(RuleTableOverflow);
    RuleTable^[NRules] := R;
  end(*add_rule*);

function RuleLess ( I, J : Integer ) : Boolean;
  begin
    if RuleTable^[RuleNo^[I]]^.LHSSym =
       RuleTable^[RuleNo^[J]]^.LHSSym then
      RuleLess := RuleNo^[I] < RuleNo^[J]
    else
      RuleLess := RuleTable^[RuleNo^[I]]^.LHSSym >
                   RuleTable^[RuleNo^[J]]^.LHSSym
  end(*rule_less*);

procedure RuleSwap ( I, J : Integer );
  var X : Integer;
  begin
    X := RuleNo^[I]; RuleNo^[I] := RuleNo^[J]; RuleNo^[J] := X;
  end(*rule_swap*);

procedure SortRules;
  var I : Integer;
  begin
    for I := 1 to NRules do RuleNo^[I] := I;
    QuickSort ( 1, NRules, {$ifdef fpc}@{$endif}RuleLess,
               {$ifdef fpc}@{$endif}RuleSwap );
  end(*sort_rules*);

procedure RuleOffsets;
  var I, Sym : Integer;
  begin
    for Sym := 1 to NNTs do with RuleOffs^[Sym] do
      begin
        RuleLo := 1; RuleHi := 0;
      end;
    I := 1;
    while (I<=NRules) do
      begin
        Sym := RuleTable^[RuleNo^[I]]^.LHSSym;
        RuleOffs^[-Sym].RuleLo := I;
        Inc(I);
        while (I<=NRules) and
              (RuleTable^[RuleNo^[I]]^.LHSSym=Sym) do
          Inc(I);
        RuleOffs^[-Sym].RuleHi := I-1;
      end;
  end(*rule_offsets*);

function NNTRules ( Sym : Integer ) : Integer;
  begin
    with RuleOffs^[-Sym] do
      NNTRules := RuleHi-RuleLo+1
  end(*n_nt_rules*);

(* Type Table routines: *)

procedure AddType ( K : Integer );
  begin
    Inc(NTypes);
    if NTypes>MaxTypes then Fatal(TypeTableOverflow);
    TypeTable^[NTypes] := K;
  end(*add_type*);

(* Routines to sort type identifiers alphabetically: *)

function TypeLess ( I, J : Integer ) : Boolean;
  begin
    TypeLess := SymTable^[TypeTable^[I]].Pname^<
                 SymTable^[TypeTable^[J]].Pname^
  end(*type_less*);

procedure TypeSwap ( I, J : Integer );
  var X : Integer;
  begin
    X := TypeTable^[I];
    TypeTable^[I] := TypeTable^[J];
    TypeTable^[J] := X;
  end(*type_swap*);

procedure SortTypes;
  var I, J, Count : Integer;
  begin
    (* sort: *)
    QuickSort(1, NTypes, {$ifdef fpc}@{$endif}TypeLess,
              {$ifdef fpc}@{$endif}TypeSwap);
    (* eliminate dups: *)
    I := 1; J := 1; Count := 0;
    while I<=NTypes do
      begin
        if I<>J then TypeTable^[J] := TypeTable^[I];
        while (I<NTypes) and (TypeTable^[I+1]=TypeTable^[I]) do
          begin
            Inc(I); Inc(Count);
          end;
        Inc(I); Inc(J);
      end;
    Dec(NTypes, Count);
  end(*sort_types*);

function SearchType ( Symbol : String ) : Boolean;
  var L, R, K : Integer;
  begin
    (* binary search: *)
    L := 1; R := NTypes;
    K := L + (R-L) div 2;
    while (L<R) and (SymTable^[TypeTable^[K]].Pname^<>Symbol) do
      begin
        if SymTable^[TypeTable^[K]].Pname^<Symbol then
          L := Succ(K)
        else
          R := Pred(K);
        K := L + (R-L) div 2;
      end;
    SearchType := (K<=NTypes) and (SymTable^[TypeTable^[K]].Pname^=Symbol);
  end(*search_type*);

(* Precedence table routines: *)

function NewPrecLevel ( PrecType : TPrecType ) : Integer;
  begin
    Inc(NPrec);
    if NPrec>MaxPrec then Fatal(PrecTableOverflow);
    PrecTable^[NPrec] := PrecType;
    NewPrecLevel := NPrec;
  end(*new_prec_level*);

(* State table: *)

procedure NewState;
  begin
    Inc(NStates);
    if NStates>MaxStates then Fatal(StateTableOverflow);
    StateTable^[NStates-1].ItemLo := NItems+1;
  end(*new_state*);

procedure AddItem ( RuleNo, PosNo : Integer );
  begin
    Inc(NItems);
    if NItems>MaxItems then Fatal(ItemTableOverflow);
    ItemTable^[NItems].RuleNo := RuleNo;
    ItemTable^[NItems].PosNo  := PosNo;
    ItemTable^[NItems].Next    := 0;
  end(*add_item*);

function AddState : Integer;
  function StateKey ( S : Integer ) : Integer;
    (* determines a hash key for state s *)
    const MaxKey = 4001;
      (* should be prime number s.t. hash keys are distributed
         evenly *)
    var I, K : Integer;
    begin
      with StateTable^[S] do
        begin
          K := 0;
          for I := ItemLo to ItemHi do
            with ItemTable^[I] do
              Inc(K, RuleNo+PosNo);
          StateKey := K mod MaxKey;
        end;
    end(*state_key*);
  function SearchState ( S, Lo, Hi : Integer; var T : Integer ) : Boolean;
    (* searches the range lo..hi in the state table for a state with the
       same kernel items as s; returns true if found, and then the
       corresponding state number in t *)
    function EqItems(S, T : Integer) : Boolean;
      (* compares kernel item sets of states s and t *)
      var I, IndexS, IndexT : Integer;
      begin
        if NStateItems(S)<>NStateItems(T) then
          EqItems := False
        else
          begin
            IndexS := StateTable^[S].ItemLo;
            IndexT := StateTable^[T].ItemLo;
            for I := 0 to NStateItems(S)-1 do
              if (ItemTable^[IndexS+I].RuleNo<>ItemTable^[IndexT+I].RuleNo) or
                 (ItemTable^[IndexS+I].PosNo<>ItemTable^[IndexT+I].PosNo) then
                begin
                  EqItems := False;
                  Exit;
                end;
            EqItems := True;
          end
      end(*eq_items*);
    var T1 : Integer;
    begin
      with StateTable^[S] do
        for T1 := Lo to Hi do
          if (Key=StateTable^[T1].Key) and
             EqItems(S, T1) then
            begin
              SearchState := True;
              T := T1;
              Exit;
            end;
      SearchState := False;
    end(*search_state*);
  var S : Integer;
  begin
    with StateTable^[NStates-1] do
      begin
        ItemHi := NItems;
        Key := StateKey(NStates-1);
        if SearchState(NStates-1, 0, NStates-2, S) then
          begin
            NItems := ItemLo;
            Dec(NStates);
            AddState := S;
          end
        else
          AddState := NStates-1;
      end;
  end(*add_state*);

procedure StartTrans;
  begin
    StateTable^[ActState].TransLo := NTrans+1;
  end(*start_trans*);

procedure AddTrans ( Sym, NextState : Integer );
  begin
    Inc(NTrans);
    if NTrans>MaxTrans then Fatal(TransTableOverflow);
    TransTable^[NTrans].Sym        := Sym;
    TransTable^[NTrans].NextState := NextState;
  end(*add_trans*);

procedure EndTrans;
  begin
    StateTable^[ActState].TransHi := NTrans;
  end(*end_trans*);

procedure StartRedns;
  begin
    StateTable^[ActState].RednsLo := NRedns+1;
  end(*start_redns*);

procedure AddRedn ( SymSet : PIntSet; RuleNo : Integer );
  begin
    Inc(NRedns);
    if NRedns>MaxRedns then Fatal(RednTableOverflow);
    RednTable^[NRedns].SymSet  := SymSet;
    RednTable^[NRedns].RuleNo := RuleNo;
  end(*add_redn*);

procedure EndRedns;
  begin
    StateTable^[ActState].RednsHi := NRedns;
  end(*end_redns*);

function NStateItems ( S : Integer ) : Integer;
  begin
    with StateTable^[S] do
      NStateItems := ItemHi-ItemLo+1
  end(*n_state_items*);

function NStateTrans ( S : Integer ) : Integer;
  begin
    with StateTable^[S] do
      NStateTrans := TransHi-TransLo+1
  end(*n_state_trans*);

function NStateRedns ( S : Integer ) : Integer;
  begin
    with StateTable^[S] do
      NStateRedns := RednsHi-RednsLo+1
  end(*n_state_redns*);

function FindItem( S : Integer; RuleNo, PosNo : Integer ) : Integer;
  var I : Integer;
  begin
    with StateTable^[S] do
      for I := ItemLo to ItemHi do
        if (ItemTable^[I].RuleNo=RuleNo) and
           (ItemTable^[I].PosNo=PosNo) then
          begin
            FindItem := I;
            Exit;
          end;
    FindItem := 0;
  end(*find_item*);

(* Item set routines: *)

procedure EmptyItemSet ( var ItemSet : TItemSet );
  begin
    ItemSet.NItems := 0;
  end(*empty_item_set*);

procedure IncludeItemSet ( var ItemSet : TItemSet;
                             RuleNo, PosNo : Integer);
  begin
    with ItemSet do
      begin
        Inc(NItems);
        if NItems>MaxSetItems then Fatal(ItemTableOverflow);
        Item[NItems].RuleNo := RuleNo;
        Item[NItems].PosNo  := PosNo;
      end;
  end(*include_item_set*);

procedure GetItemSet ( S : Integer; var ItemSet : TItemSet);
  begin
    with StateTable^[S], ItemSet do
      begin
        NItems := NStateItems(S);
        Move(ItemTable^[ItemLo], Item, NItems*SizeOf(TItemRec));
      end
  end(*get_item_set*);

procedure Closure ( var ItemSet : TItemSet );
  var I, J : Integer;
      NTSyms0, NTSyms : TIntSet;
  begin
    with ItemSet do
      begin
        (* get the nonterminals at current positions in items: *)
        Empty(NTSyms0);
        for I := 1 to NItems do
          with Item[I], RuleTable^[RuleNo]^ do
            if (PosNo<=RHSLen) and (RHSSym[PosNo]<0) then
              Include(NTSyms0, RHSSym[PosNo]);
        NTSyms := NTSyms0;
        (* add closure symbols: *)
        for I := 1 to Size(NTSyms0) do
          SetUnion(NTSyms, ClosureTable^[-NTSyms0[I]]^);
        (* add the nonkernel items for the nonterminal symbols: *)
        for I := 1 to Size(NTSyms) do
          with RuleOffs^[-NTSyms[I]] do
            for J := RuleLo to RuleHi do
              IncludeItemSet(ItemSet, RuleNo^[J], 1);
      end;
  end(*closure*);

var SortItems : TItemSet;

(* comparison and swap routines for sort_item_set: *)

function ItemsLess ( I, J : Integer ) : Boolean;
  begin
    with SortItems do
      if Item[I].PosNo=Item[J].PosNo then
        ItemsLess := Item[I].RuleNo<Item[J].RuleNo
      else
        ItemsLess := Item[I].PosNo>Item[J].PosNo
  end(*items_less*);

procedure ItemsSwap ( I, J : Integer );
  var X : TItemRec;
  begin
    with SortItems do
      begin
        X := Item[I]; Item[I] := Item[J]; Item[J] := X;
      end
  end(*items_swap*);

procedure SortItemSet ( var ItemSet : TItemSet );
  begin
    SortItems := ItemSet;
    QuickSort(1, SortItems.NItems, {$ifdef fpc}@{$endif}ItemsLess,
              {$ifdef fpc}@{$endif}ItemsSwap);
    ItemSet := SortItems;
  end(*sort_item_set*);

var I : Integer;

begin

  Verbose          := False;
  Debug            := False;
  StartNT          := 0;

  NNTs            := 1;
  NLits           := 257;
  NRules          := 0;
  NTypes          := 0;
  NPrec           := 0;
  NStates         := 0;
  NItems          := 0;
  NTrans          := 0;
  NRedns          := 0;

  (* allocate tables: *)

  New(SymTable);
  New(SymKey);
  New(RuleTable);
  New(RuleNo);
  New(RuleOffs);
  New(TypeTable);
  New(SymType);
  New(PrecTable);
  New(SymPrec);
  New(RulePrec);
  New(ClosureTable);
  New(FirstSetTable);
  New(Nullable);
  New(StateTable);
  New(ItemTable);
  New(TransTable);
  New(RednTable);
  New(LookaheadTable);
  New(PropTable);

  (* initialize symbol table: *)

  for I := 1 to MaxKeys do
    with SymTable^[I] do
      begin
        Pname := nil;
        Deff  := False;
      end;

  (* enter predefined error symbol into symbol table: *)

  DefKey(GetKey('error'), 256);

  (* initialize type and precedence tables: *)

  for I := -MaxNTs to MaxLits-1 do SymType^[I] := 0;
  for I := 0 to MaxLits-1 do SymPrec^[I] := 0;
  for I := 1 to MaxRules do RulePrec^[I] := 0;

end(*YaccTables*).
