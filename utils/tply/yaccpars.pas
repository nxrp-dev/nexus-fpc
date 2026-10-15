{
  Yacc parse table construction.


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

$History: YACCPARS.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit YaccPars;

interface


procedure ParseTable;

  (* Constructs the parse table from the information in the state,
     transition and reduction table, and writes parse and rule table
     information to the output file.

     Rules never reduced are detected, and parsing conflicts resolved
     according to the usual disambiguting rules:

     - by default, shift/reduce conflicts are resolved in favour of
       shift, and reduce/reduce conflicts are resolved in favour of
       the rule appearing first in the grammar

     - in the presence of precedence information, shift/reduce conflicts
       are resolved as follows:
       - if the rule has higher precedence than the input symbol,
         reduce
       - if the input symbol has higher precedence than the rule,
         shift
       - if rule and input symbol have the same precedence, use
         associativity to resolve the conflict: if the symbol is
         left-associative, reduce; if right-associative, shift;
         if nonassociative, error.

     The default action for any state is error, unless the state
     only has a single reduce action, and no shift (or nonassoc-induced
     error) actions, in which case the default action is the reduction.
     An accept action is generated for the shift-endmarker action.

     If the verbose option is enabled, the parse_table routine also writes
     a readable listing of the generated parser to the .LST file, including
     descriptions of parse conflicts and rules never reduced.

     Parse table actions are encoded as follows:
     - positive: next state (shift or goto action)
     - negative: rule to reduce (reduce action)
     - 0: error (in default action table) or accept (in shift/reduce
          action table)

     The tables are written out as a collection of typed array constants:

     type YYARec = record { action record }
                     sym, act : Integer; { symbol and action }
                   end;
          YYRRec = record { rule record }
                     len, sym : Integer; { length and lhs symbol }
                   end;

     const

     yynacts   = ...; { number of parse table (shift and reduce) actions }
     yyngotos  = ...; { number of goto actions }
     yynstates = ...; { number of states }
     yynrules  = ...; { number of rules }

     yya : array [1..yynacts] of YYARec = ...;
       { shift and reduce actions }
     yyg : array [1..yyngotos] of YYARec = ...;
       { goto actions }
     yyd : array [0..yynstates-1] of Integer = ...;
       { default actions }
     yyal, yyah,
     yygl, yygh : array [0..yynstates-1] of Integer = ...;
       { offsets into action and goto table }

     yyr : array [1..yynrules] of YYRRec = ...;

  *)

var ShiftReduce, ReduceReduce, NeverReduced : Integer;
  (* number of parsing conflicts and unreduced rules detected during
     parse table generation *)

implementation

uses YaccBase, YaccTabl;

var Reduced : array [1..MaxRules] of Boolean;

var YYNActs, YYNGotos, YYNStates : Integer;
    YYD : array [0..MaxStates-1] of Integer;
    YYAL, YYAH, YYGL, YYGH : array [0..MaxStates-1] of Integer;

function RuleStr ( I : Integer ) : String;
  (* returns print representation of rule number i *)
  var Str : String; J : Integer;
  begin
    with RuleTable^[I]^ do
      begin
        Str := Pname(LHSSym)+' :';
        for J := 1 to RHSLen do
          Str := Str+' '+Pname(RHSSym[J]);
      end;
    RuleStr := Str;
  end(*ruleStr*);

function ItemStr ( var ItemSet : TItemSet; I : Integer ) : String;
  (* returns print representation of item number i in item_set *)
  var Str : String; J : Integer;
  begin
    with ItemSet, Item[I], RuleTable^[RuleNo]^ do
      begin
        Str := Pname(LHSSym)+' :';
        for J := 1 to PosNo-1 do
          Str := Str+' '+Pname(RHSSym[J]);
        Str := Str+' _';
        for J := PosNo to RHSLen do
          Str := Str+' '+Pname(RHSSym[J]);
      end;
    ItemStr := Str;
  end(*itemStr*);

procedure Build;

  (* build the parse table, resolve conflicts *)

  var

    I, J, K, S,
    NErrors,
    NShifts,
    NGotos,
    NReductions,
    NConflicts : Integer;

  ItemSet : TItemSet;

  begin

    (* initialize: *)

    ShiftReduce := 0; ReduceReduce := 0; NeverReduced := 0;
    for I := 1 to NRules do Reduced[I] := False;

    (* traverse the state table: *)

    for S := 0 to NStates-1 do with StateTable^[S] do

      begin

        if Verbose then
          begin
            WriteLn(YYLst);
            WriteLn(YYLst, 'state ', S, ':');
          end;

        (* Check shift and reduce actions, resolve conflicts.
           The number of error actions generated by nonassoc's is counted
           in n_errors, the number of conflicts reported in n_conflicts.
           Shift actions ruled out by disambiguating rules are flagged by
           setting the corresponding next_state to -1. *)

        NErrors := 0; NConflicts := 0;

        for I := TransLo to TransHi do with TransTable^[I] do
          if Sym>=0 then
            for J := RednsLo to RednsHi do with RednTable^[J] do
              if Member(Sym, SymSet^) then
                if (SymPrec^[Sym]>0) and (RulePrec^[RuleNo]>0) then
                  (* resolve conflict using precedence: *)
                  if RulePrec^[RuleNo]=SymPrec^[Sym] then
                    case PrecTable^[SymPrec^[Sym]] of
                      Left     : (* reduce *)
                                 NextState := -1;
                      Right    : (* shift *)
                                 Exclude(SymSet^, Sym);
                      NonAssoc : (* error *)
                                 begin
                                   Inc(NErrors);
                                   NextState := -1;
                                   Exclude(SymSet^, Sym);
                                 end;
                    end
                  else if RulePrec^[RuleNo]>SymPrec^[Sym] then
                    (* reduce *)
                    NextState := -1
                  else
                    (* shift *)
                    Exclude(SymSet^, Sym)
                else
                  (* shift/reduce conflict: *)
                  begin
                    if Verbose then
                      begin
                        if NConflicts=0 then
                          begin
                            WriteLn(YYLst);
                            WriteLn(YYLst, Tab, '*** conflicts:');
                            WriteLn(YYLst);
                          end;
                        WriteLn(YYLst, Tab,
                                       'shift ', NextState, ', ',
                                       'reduce ', RuleNo-1, ' on ',
                                       Pname(Sym));
                      end;
                    Inc(NConflicts); Inc(ShiftReduce);
                    Exclude(SymSet^, Sym);
                  end;

        for I := RednsLo to RednsHi do
          for J := I+1 to RednsHi do with RednTable^[J] do
            begin
              for K := 1 to Size(SymSet^) do
                if Member(SymSet^[K], RednTable^[I].SymSet^) then
                  (* reduce/reduce conflict: *)
                  begin
                    if Verbose then
                      begin
                        if NConflicts=0 then
                          begin
                            WriteLn(YYLst);
                            WriteLn(YYLst, Tab, '*** conflicts:');
                            WriteLn(YYLst);
                          end;
                        WriteLn(YYLst, Tab,
                                       'reduce ',
                                       RednTable^[I].RuleNo-1, ', ',
                                       'reduce ', RuleNo-1, ' on ',
                                       Pname(SymSet^[K]));
                      end;
                    Inc(NConflicts); Inc(ReduceReduce);
                  end;
              SetMinus(SymSet^, RednTable^[I].SymSet^);
            end;

        (* Count goto, shift and reduce actions to generate. *)

        NGotos := 0; NShifts := 0; NReductions := 0;

        for I := TransLo to TransHi do with TransTable^[I] do
          if NextState<>-1 then
            if Sym<0 then
              Inc(NGotos)
            else
              Inc(NShifts);

        for I := RednsLo to RednsHi do with RednTable^[I] do
          if Size(SymSet^)>0 then
            Inc(NReductions);

        (* Determine default action. *)

        if (NShifts+NErrors=0) and (NReductions=1) then
          (* default action is the reduction *)
          with RednTable^[RednsLo] do
            YYD[S] := -(RuleNo-1)
        else
          (* default action is error *)
          YYD[S] := 0;

        (* Flag reduced rules. *)

        for I := RednsLo to RednsHi do
          with RednTable^[I] do
            Reduced[RuleNo] := True;

        if Verbose then

          begin

            (* List kernel items. *)

            WriteLn(YYLst);
            GetItemSet(S, ItemSet);
            Closure(ItemSet);
            SortItemSet(ItemSet);
            with ItemSet do
              begin
                for I := 1 to NItems do
                  with Item[I], RuleTable^[RuleNo]^ do
                    if (RuleNo=1) or (PosNo>1) or (RHSLen=0) then
                      if PosNo>RHSLen then
                        WriteLn(YYLst, Tab,
                                       ItemStr(ItemSet, I), Tab,
                                       '(', RuleNo-1, ')')
                      else
                        WriteLn(YYLst, Tab, ItemStr(ItemSet, I));
              end;

            (* List parse actions. *)

            (* shift, reduce and default actions: *)

            if (NShifts+NErrors=0) and (NReductions=1) then
              (* default action is the reduction *)
              with RednTable^[RednsLo] do
                begin
                  WriteLn(YYLst);
                  WriteLn(YYLst, Tab, '.', Tab, 'reduce ', RuleNo-1 );
                end
            else
              (* default action is error *)
              begin
                WriteLn(YYLst);
                for I := TransLo to TransHi do with TransTable^[I] do
                  if NextState<>-1 then
                    if Sym=0 then
                      (* accept action *)
                      WriteLn(YYLst, Tab, Pname(Sym), Tab, 'accept')
                    else if Sym>0 then
                      (* shift action *)
                      WriteLn(YYLst, Tab,
                                     Pname(Sym), Tab, 'shift ', NextState);
                for I := RednsLo to RednsHi do
                  with RednTable^[I] do
                    for J := 1 to Size(SymSet^) do
                      (* reduce action *)
                      WriteLn(YYLst, Tab,
                                     Pname(SymSet^[J]), Tab, 'reduce ',
                                     RuleNo-1);
                (* error action *)
                WriteLn(YYLst, Tab, '.', Tab, 'error');
              end;

            (* goto actions: *)

            if NGotos>0 then
              begin
                WriteLn(YYLst);
                for I := TransLo to TransHi do with TransTable^[I] do
                  if Sym<0 then
                    WriteLn(YYLst, Tab,
                                   Pname(Sym), Tab, 'goto ', NextState);
              end;

          end;

      end;

    for I := 2 to NRules do
      if not Reduced[I] then Inc(NeverReduced);

    if Verbose then
      begin
        WriteLn(YYLst);
        if ShiftReduce>0 then
          WriteLn(YYLst, ShiftReduce, ' shift/reduce conflicts.');
        if ReduceReduce>0 then
          WriteLn(YYLst, ReduceReduce, ' reduce/reduce conflicts.');
        if NeverReduced>0 then
          WriteLn(YYLst, NeverReduced, ' rules never reduced.');
      end;

    (* report rules never reduced: *)

    if (NeverReduced>0) and Verbose then
      begin
        WriteLn(YYLst);
        WriteLn(YYLst, '*** rules never reduced:');
        for I := 2 to NRules do if not Reduced[I] then
          begin
            WriteLn(YYLst);
            WriteLn(YYLst, RuleStr(I), Tab, '(', I-1, ')');
          end;
      end;

  end(*build*);

procedure Counters;

  (* initialize counters and offsets *)

  var S, I : Integer;

  begin

    YYNStates := NStates; YYNActs := 0; YYNGotos := 0;

    for S := 0 to NStates-1 do with StateTable^[S] do
      begin
        YYAL[S] := YYNActs+1; YYGL[S] := YYNGotos+1;
        if YYD[S]=0 then
          begin
            for I := TransLo to TransHi do with TransTable^[I] do
              if (Sym>=0) and (NextState<>-1) then
                Inc(YYNActs);
            for I := RednsLo to RednsHi do with RednTable^[I] do
              Inc(YYNActs, Size(SymSet^));
          end;
        for I := TransLo to TransHi do with TransTable^[I] do
          if Sym<0 then
            Inc(YYNGotos);
        YYAH[S] := YYNActs; YYGH[S] := YYNGotos;
      end;

  end(*counters*);

procedure Tables;

  (* write tables to output file *)

  var S, I, J, Count : Integer;

  begin

    WriteLn(YYOut);
    WriteLn(YYOut, 'type TYYARec = record');
    WriteLn(YYOut, '                Sym, Act : Integer;');
    WriteLn(YYOut, '              end;');
    WriteLn(YYOut, '     TYYRRec = record');
    WriteLn(YYOut, '                Len, Sym : Integer;');
    WriteLn(YYOut, '              end;');
    WriteLn(YYOut);
    WriteLn(YYOut, 'const');

    (* counters: *)

    WriteLn(YYOut);
    WriteLn(YYOut, 'YYNActs   = ', YYNActs, ';');
    WriteLn(YYOut, 'YYNGotos  = ', YYNGotos, ';');
    WriteLn(YYOut, 'YYNStates = ', YYNStates, ';');
    WriteLn(YYOut, 'YYNRules  = ', NRules-1, ';');

    (* shift/reduce table: *)

    WriteLn(YYOut);
    WriteLn(YYOut, 'YYA : array [1..YYNActs] of TYYARec = (');
    Count := 0;
    for S := 0 to NStates-1 do with StateTable^[S] do
      begin
        WriteLn(YYOut, '{ ', S, ': }');
        if YYD[S]=0 then
          begin
            for I := TransLo to TransHi do with TransTable^[I] do
              if (NextState<>-1) and (Sym>=0) then
                begin
                  Inc(Count);
                  if Sym=0 then
                    Write(YYOut, '  ( Sym: 0; Act: 0 )')
                  else
                    Write(YYOut, '  ( Sym: ', Sym, '; Act: ',
                                 NextState, ' )');
                  if Count<YYNActs then Write(YYOut, ',');
                  WriteLn(YYOut);
                end;
            for I := RednsLo to RednsHi do with RednTable^[I] do
              for J := 1 to Size(SymSet^) do
                begin
                  Inc(Count);
                  Write(YYOut, '  ( Sym: ', SymSet^[J], '; Act: ',
                               -(RuleNo-1), ' )');
                  if Count<YYNActs then Write(YYOut, ',');
                  WriteLn(YYOut);
                end;
        end;
      end;
    WriteLn(YYOut, ');');

    (* goto table: *)

    WriteLn(YYOut);
    WriteLn(YYOut, 'YYG : array [1..YYNGotos] of TYYARec = (');
    Count := 0;
    for S := 0 to NStates-1 do with StateTable^[S] do
      begin
        WriteLn(YYOut, '{ ', S, ': }');
        for I := TransLo to TransHi do with TransTable^[I] do
          if Sym<0 then
            begin
              Inc(Count);
              Write(YYOut, '  ( Sym: ', Sym, '; Act: ', NextState, ' )');
              if Count<YYNGotos then Write(YYOut, ',');
              WriteLn(YYOut);
            end;
      end;
    WriteLn(YYOut, ');');

    (* default action table: *)

    WriteLn(YYOut);
    WriteLn(YYOut, 'YYD : array [0..YYNStates-1] of Integer = (');
    for S := 0 to NStates-1 do
      begin
        Write(YYOut, '{ ', S, ': } ', YYD[S]);
        if S<NStates-1 then Write(YYOut, ',');
        WriteLn(YYOut);
      end;
    WriteLn(YYOut, ');');

    (* offset tables: *)

    WriteLn(YYOut);
    WriteLn(YYOut, 'YYAL : array [0..YYNStates-1] of Integer = (');
    for S := 0 to NStates-1 do
      begin
        Write(YYOut, '{ ', S, ': } ', YYAL[S]);
        if S<NStates-1 then Write(YYOut, ',');
        WriteLn(YYOut);
      end;
    WriteLn(YYOut, ');');
    WriteLn(YYOut);
    WriteLn(YYOut, 'YYAH : array [0..YYNStates-1] of Integer = (');
    for S := 0 to NStates-1 do
      begin
        Write(YYOut, '{ ', S, ': } ', YYAH[S]);
        if S<NStates-1 then Write(YYOut, ',');
        WriteLn(YYOut);
      end;
    WriteLn(YYOut, ');');
    WriteLn(YYOut);
    WriteLn(YYOut, 'YYGL : array [0..YYNStates-1] of Integer = (');
    for S := 0 to NStates-1 do
      begin
        Write(YYOut, '{ ', S, ': } ', YYGL[S]);
        if S<NStates-1 then Write(YYOut, ',');
        WriteLn(YYOut);
      end;
    WriteLn(YYOut, ');');
    WriteLn(YYOut);
    WriteLn(YYOut, 'YYGH : array [0..YYNStates-1] of Integer = (');
    for S := 0 to NStates-1 do
      begin
        Write(YYOut, '{ ', S, ': } ', YYGH[S]);
        if S<NStates-1 then Write(YYOut, ',');
        WriteLn(YYOut);
      end;
    WriteLn(YYOut, ');');

    (* rule table: *)

    WriteLn(YYOut);
    WriteLn(YYOut, 'YYR : array [1..YYNRules] of TYYRRec = (');
    for I := 2 to NRules do with RuleTable^[I]^ do
      begin
        Write(YYOut, '{ ', I-1, ': } ', '( Len: ', RHSLen,
                                        '; Sym: ', LHSSym, ' )');
        if I<NRules then Write(YYOut, ',');
        WriteLn(YYOut);
      end;
    WriteLn(YYOut, ');');

    WriteLn(YYOut);

  end(*tables*);

procedure ParseTable;
  begin
    Build; Counters; Tables;
  end(*parse_table*);

end(*YaccParseTable*).
