{
    Dynamic set

    Copyright (c) 2007-2026 by Florian Klaempfl

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
unit cdynset;

{$i fpcdefs.inc}

  interface


    type
      TDynSet = array of Byte;
      PDynSet = ^TDynSet;

    { add e to s }
    procedure DynSetInclude(var S : TDynSet;E : Integer);

    { add s to d }
    procedure DynSetIncludeSet(var D : TDynSet;const S : TDynSet);

    { remove s to d }
    procedure DynSetExcludeSet(var D : TDynSet;const S : TDynSet);

    { remove e from s }
    procedure DynSetExclude(var S : TDynSet;E : Integer);

    { test if s contains e }
    function DynSetIn(const S : TDynSet;E : Integer) : Boolean;

    { d:=s1+s2; }
    procedure DynSetUnion(var D : TDynSet;const S1,S2 : TDynSet);

    { d:=s1*s2; }
    procedure DynSetIntersect(var D : TDynSet;const S1,S2 : TDynSet);

    { d:=s1-s2; }
    procedure DynSetDiff(var D : TDynSet;const S1,S2 : TDynSet);

    { s1<>s2; }
    function DynSetNotEqual(const S1,S2 : TDynSet) : Boolean;

    { output DynSet }
    procedure PrintDynSet(var F : Text;S : TDynSet);

  implementation

    uses
      CUtils;

    procedure DynSetInclude(var S : TDynSet;E : Integer);
      var
        E8 : Integer;
      begin
        E8:=E div 8;
        if E8>High(S) then
          SetLength(S,E8+1);
        S[E8]:=S[E8] or (1 shl (E mod 8));
      end;


    procedure DynSetIncludeSet(var D : TDynSet;const S : TDynSet);
      var
        I : Integer;
      begin
        if Length(S)>Length(D) then
          SetLength(D,Length(S));
        for I:=0 to High(S) do
          D[I]:=D[I] or S[I];
      end;


    procedure DynSetExcludeSet(var D : TDynSet;const S : TDynSet);
      var
        I : Integer;
      begin
        if Length(S)>Length(D) then
          SetLength(D,Length(S));
        for I:=0 to High(S) do
          D[I]:=D[I] and not(S[I]);
      end;


    procedure DynSetExclude(var S : TDynSet;E : Integer);
      var
        E8 : Integer;
      begin
        E8:=E div 8;
        if E8<=High(S) then
          S[E8]:=S[E8] and not(1 shl (E mod 8));
      end;


    function DynSetIn(const S : TDynSet;E : Integer) : Boolean;
      var
        E8 : Integer;
      begin
        E8:=E div 8;
        if E8<=High(S) then
          Result:=(S[E8] and (1 shl (E mod 8)))<>0
        else
          Result:=False;
      end;


    procedure DynSetUnion(var D : TDynSet;const S1,S2 : TDynSet);
      var
        I : Integer;
      begin
        SetLength(D,Max(Length(S1),Length(S2)));
        for I:=0 to Min(High(S1),High(S2)) do
          D[I]:=S1[I] or S2[I];
        if High(S1)<High(S2) then
          for I:=High(S1)+1 to High(S2) do
            D[I]:=S2[I]
        else
          for I:=High(S2)+1 to High(S1) do
            D[I]:=S1[I];
      end;


    procedure DynSetIntersect(var D : TDynSet;const S1,S2 : TDynSet);
      var
        I : Integer;
      begin
        SetLength(D,Min(Length(S1),Length(S2)));
        for I:=0 to High(D) do
          D[I]:=S1[I] and S2[I];
      end;


    procedure DynSetDiff(var D : TDynSet;const S1,S2 : TDynSet);
      var
        I : Integer;
      begin
        SetLength(D,Length(S1));
        for I:=0 to High(D) do
          if I>High(S2) then
            D[I]:=S1[I]
          else
            D[I]:=S1[I] and not(S2[I]);
      end;


    function DynSetNotEqual(const S1,S2 : TDynSet) : Boolean;
      var
        I : Integer;
      begin
        Result:=True;
        { one set could be larger than the other }
        if Length(S1)>Length(S2) then
          begin
            for I:=0 to High(S2) do
              if S1[I]<>S2[I] then
                Exit;
            { check remaining part being zero }
            for I:=Length(S2) to High(S1) do
              if S1[I]<>0 then
                Exit;
          end
        else
          begin
            for I:=0 to High(S1) do
              if S1[I]<>S2[I] then
                Exit;
            { check remaining part being zero }
            for I:=Length(S1) to High(S2) do
              if S2[I]<>0 then
                Exit;
          end;
        Result:=False;
      end;


    procedure PrintDynSet(var F : Text;S : TDynSet);
      var
        I : Integer;
        First : Boolean;
      begin
        First:=True;
        for I:=0 to Length(S)*8 do
          begin
            if DynSetIn(S,I) then
              begin
                if not(First) then
                  Write(F,',');
                Write(F,I);
                First:=False;
              end;
          end;
      end;


end.

