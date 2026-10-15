{
  Construct the position table, as well as first position sets.

  The position table stores symbol positions in regular expressions of
  the Lex grammar. It also allows to store the corresponding first
  and follow sets. By this means, the position table represents an eps-
  free nondeterministic automaton for the regular expressions of the
  Lex grammar (cf. Aho/Sethi/Ullman, Compilers : Principles, Techniques
  and Tools, 1986, Section 3.9, on constructing NFA's from regular
  expressions using position tables).


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
$Modtime: 96-08-01 6:30 $

$History: LEXPOS.PAS $
 *
 * *****************  Version 2  *****************
 * User: Berend       Date: 96-10-10   Time: 21:16
 * Updated in $/Lex and Yacc/tply
 * Updated for protected mode, windows and Delphi 1.X and 2.X.

}


unit LexPos;


interface

uses LexBase, LexTable;


procedure AddExpr(R : PRegExpr; var First : TIntSet);
  (* Add the positions in r to the position table, and return the set of
     first positions of r. *)

implementation

procedure Eval(R : PRegExpr;
               var First, Last : TIntSet;
               var Nullable : Boolean);
  (* Evaluates the expression r, adding the positions in r to the position
     table and assigning FIRST, LAST and FOLLOW sets accordingly (cf. Aho/
     Sethi/Ullman, Compilers : Principles, Techniques and Tools, Section 3.9).
     Returns:
     - FIRST: the set of first positions in r
     - LAST: the set of last positions in r
     - nullable: denotes whether the r is nullable (i.e. is matched by the
       empty string). *)
  var
    C : Char;
    Str : PStr;
    CC : PCClass;
    Rule, POS : Integer;
    R1, R2 : PRegExpr;
    First1, Last1 : TIntSet;
    Nullable1 : Boolean;
    I : Integer;
  begin
    if IsEpsExpr(R) then
      begin
        Empty(First); Empty(Last);
        Nullable := True
      end
    else if IsMarkExpr(R, Rule, POS) then
      begin
        AddMarkPos(Rule, POS);
        Singleton(First, NPos); Singleton(Last, NPos);
        Nullable := True
      end
    else if IsCharExpr(R, C) then
      begin
        AddCharPos(C);
        Singleton(First, NPos); Singleton(Last, NPos);
        Nullable := False
      end
    else if IsStrExpr(R, Str) then
      if Length(Str^)=0 then
        (* empty string is treated as empty expression *)
        begin
          Empty(First); Empty(Last);
          Nullable := True
        end
      else
        begin
          AddCharPos(Str^[1]);
          Singleton(First, NPos);
          for I := 2 to Length(Str^) do
            begin
              AddCharPos(Str^[I]);
              Singleton(PosTable^[Pred(NPos)].FollowPos^, NPos);
            end;
          Singleton(Last, NPos);
          Nullable := False
        end
    else if IsCClassExpr(R, CC) then
      begin
        AddCClassPos(CC);
        Singleton(First, NPos); Singleton(Last, NPos);
        Nullable := False
      end
    else if IsStarExpr(R, R1) then
      begin
        Eval(R1, First, Last, Nullable);
        for I := 1 to Size(Last) do
          SetUnion(PosTable^[Last[I]].FollowPos^, First);
        Nullable := True
      end
    else if IsPlusExpr(R, R1) then
      begin
        Eval(R1, First, Last, Nullable);
        for I := 1 to Size(Last) do
          SetUnion(PosTable^[Last[I]].FollowPos^, First);
      end
    else if IsOptExpr(R, R1) then
      begin
        Eval(R1, First, Last, Nullable);
        Nullable := True
      end
    else if IsCatExpr(R, R1, R2) then
      begin
        Eval(R1, First, Last1, Nullable);
        Eval(R2, First1, Last, Nullable1);
        for I := 1 to Size(Last1) do
          SetUnion(PosTable^[Last1[I]].FollowPos^, First1);
        if Nullable then SetUnion(First, First1);
        if Nullable1 then SetUnion(Last, Last1);
        Nullable := Nullable and Nullable1
      end
    else if IsAltExpr(R, R1, R2) then
      begin
        Eval(R1, First, Last, Nullable);
        Eval(R2, First1, Last1, Nullable1);
        SetUnion(First, First1);
        SetUnion(Last, Last1);
        Nullable := Nullable or Nullable1
      end
  end(*eval*);

procedure AddExpr(R : PRegExpr; var First : TIntSet);
  var Last : TIntSet;
      Nullable : Boolean;
  begin
    Eval(R, First, Last, Nullable);
  end(*addExpr*);

end(*LexPos*).
