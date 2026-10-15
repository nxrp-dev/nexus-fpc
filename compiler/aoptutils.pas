{
    Copyright (c) 1998-2016 by Florian Klaempfl and Jonas Maebe

    This unit contains helper procedures for the assembler peephole optimizer

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

 ****************************************************************************
}

unit aoptutils;

{$i fpcdefs.inc}

  interface

    uses
      cpubase,aasmtai,aasmcpu;

    function MatchOpType(const p : TAICPU;type0: TOpType) : Boolean;
    function MatchOpType(const p : TAICPU;type0,type1 : TOpType) : Boolean;
    function MatchOpType(const p : TAICPU; type0,type1,type2 : TOpType) : Boolean;

    { skips all labels and returns the next "real" instruction }
    function SkipLabels(hp: TAI; out hp2: TAI): boolean;

    { sets hp2 to hp and returns True if hp is not nil }
    function SetAndTest(const hp: TAI; out hp2: TAI): Boolean; inline;

    { Set Store and Result to Condition (useful as an inline assignment in a conditional block) }
    function SetAndTest(const Condition: Boolean; out Store: Boolean): Boolean; inline;

    { Set result and store to value (useful as an inline assignment in a conditional block).
      This is the equivalent of the C code "if ((store=value)==...)" }
    function SetAndPassThrough(const value: integer; out store: integer): integer; inline;

  implementation

    uses
      aasmbase;


    function MatchOpType(const p : TAICPU; type0: TOpType) : Boolean; inline;
      begin
        Result:=(p.ops=1) and (p.oper[0]^.typ=type0);
      end;


    function MatchOpType(const p : TAICPU; type0,type1 : TOpType) : Boolean; inline;
      begin
        Result:=(p.ops=2) and (p.oper[0]^.typ=type0) and (p.oper[1]^.typ=type1);
      end;


    function MatchOpType(const p : TAICPU; type0,type1,type2 : TOpType) : Boolean; inline;
      begin
        Result:=(p.ops=3) and (p.oper[0]^.typ=type0) and (p.oper[1]^.typ=type1) and (p.oper[2]^.typ=type2);
      end;

    { skips all labels and returns the next "real" instruction }
    function SkipLabels(hp: TAI; out hp2: TAI): boolean;
      begin
        while Assigned(hp.next) and
              (TAI(hp.next).typ in SkipInstr + [ait_label]) Do
          hp := TAI(hp.next);
        if Assigned(hp.next) then
          begin
            SkipLabels := True;
            hp2 := TAI(hp.next)
          end
        else
          begin
            hp2 := hp;
            SkipLabels := False
          end;
      end;

    { sets hp2 to hp and returns True if hp is not nil }
    function SetAndTest(const hp: TAI; out hp2: TAI): Boolean;
      begin
        hp2 := hp;
        Result := Assigned(hp);
      end;


    { Set Store and Result to Condition (useful as an inline assignment in a conditional block) }
    function SetAndTest(const Condition: Boolean; out Store: Boolean): Boolean;
      begin
        Store := Condition;
        Result := Store;
      end;


    { Set result and store to value (useful as an inline assignment in a conditional block).
      This is the equivalent of the C code "if ((store=value)==...)" }
    function SetAndPassThrough(const value: integer; out store: integer): integer;
      begin
        store := value;
        result := value;
      end;

end.
