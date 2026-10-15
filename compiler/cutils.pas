{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements some support functions

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published
    by the Free Software Foundation; either version 2 of the License, or
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
{# This unit contains some generic support functions which are used
   in the different parts of the compiler.
}
unit cutils;

{$i fpcdefs.inc}

interface

  uses
    TPCompilerReal,ConstExp;

  type
    Tcharset=set of Char;

  var
    InternalErrorProc : procedure(i:LongInt);


    {# Returns the minimal value between @var(a) and @var(b) }
    function Min(A,B : LongInt) : LongInt;{$ifdef USEINLINE}inline;{$endif}
    function Min(A,B : Int64) : Int64;{$ifdef USEINLINE}inline;{$endif}
    function Min(A,B : QWord) : QWord;{$ifdef USEINLINE}inline;{$endif}
    {# Returns the maximum value between @var(a) and @var(b) }
    function Max(A,B : LongInt) : LongInt;{$ifdef USEINLINE}inline;{$endif}
    function Max(A,B : Int64) : Int64;{$ifdef USEINLINE}inline;{$endif}
    function Max(A,B : QWord) : QWord;{$ifdef USEINLINE}inline;{$endif}

    { These functions are intentionally put here and not in the constexp unit.
      Since Tconstexprint may be automatically converted to int, which causes
      loss of data and since there are already min and max functions for ints in
      this unit, we put min and max for Tconstexprint as well. This way we avoid
      potential bugs, caused by code unintentionally calling the int versions of
      min/max on Tconstexprint, because of only including cutils and forgetting
      the constexp unit in the uses clause. }
    function Min(const A,B : TConstExprInt) : TConstExprInt;{$ifdef USEINLINE}inline;{$endif}
    function Max(const A,B : TConstExprInt) : TConstExprInt;{$ifdef USEINLINE}inline;{$endif}

    {# Return value @var(i) aligned on @var(a) boundary }
    function Align(I,A:LongInt):LongInt;{$ifdef USEINLINE}inline;{$endif}
    function Align(I,A:Int64):Int64;{$ifdef USEINLINE}inline;{$endif}
    function Align(I,A:QWord):QWord;{$ifdef USEINLINE}inline;{$endif}
    { if you have an address aligned using "oldalignment" and add an
      offset of (a multiple of) offset to it, this function calculates
      the new minimally guaranteed alignment
    }
    function NewAlignment(OldAlignment: LongInt; Offset: Int64): LongInt;
    {# Return @var(b) with the bit order reversed }
    function Reverse_Byte(B: Byte): Byte;
    {# Return @var(w) with the bit order reversed }
    function Reverse_Word(W: Word): Word;
    {# Return @var(l) with the bit order reversed }
    function Reverse_LongWord(L: LongWord): LongWord;

    function Next_Prime(L: LongInt): LongInt;

    function Used_Align(VarAlign,MinAlign,MaxAlign:LongInt):LongInt;
    function IsBetterAlignedThan(New, Org, Limit: Cardinal): Boolean;
    function PackedBitsLoadSize(BitLen: Int64) : Int64;
    procedure Replace(var S:ShortString;S1:ShortString;const S2:ShortString);
    procedure Replace(var S:AnsiString;S1:ShortString;const S2:AnsiString);
    procedure ReplaceCase(var S:ShortString;const S1,S2:ShortString);
    procedure ReplaceCase(var S:AnsiString;const S1,S2:AnsiString);
    Function MatchPattern(const Pattern,What:string):Boolean;
    function Upper(const C : Char) : Char;
    function Upper(const S : ShortString) : ShortString;
    function Upper(const S : AnsiString) : AnsiString;
    function Lower(const C : Char) : Char;
    function Lower(const S : ShortString) : ShortString;
    function Lower(const S : AnsiString) : AnsiString;
    function RPos(const Needle: Char; const Haystack: ShortString): LongInt; overload;
    function RPos(const Needle: ShortString; const Haystack: ShortString): LongInt; overload;
    function TrimSpace(const S:ShortString):ShortString;
    function TrimSpace(const S:AnsiString):AnsiString;
    function Space (B : LongInt): ShortString;
    { returns the position of the first char of the set cs in s, if there is none, then it returns 0 }
    function PosCharset(const CS : TCharSet;const S : AnsiString) : Integer;
    function PadSpace(const S:ShortString;Len:LongInt):ShortString;
    function PadSpace(const S:AnsiString;Len:LongInt):AnsiString;
    function GetToken(var S:ShortString;EndChar:Char):ShortString;
    function GetToken(var S:AnsiString;EndChar:Char):AnsiString;
    procedure UpperVar(var S : ShortString);
    function RealToStr(E:BestReal):string;{$ifdef USEINLINE}inline;{$endif}
    function ToStr(I : QWord) : string;{$ifdef USEINLINE}inline;{$endif}overload;
    function ToStr(I : Int64) : string;{$ifdef USEINLINE}inline;{$endif}overload;
    function ToStr(I : LongInt) : string;{$ifdef USEINLINE}inline;{$endif}overload;
    function ToStr_With_Plus(I : Int64) : string;{$ifdef USEINLINE}inline;{$endif}
    function DStr(L:LongInt):string;
    {# Returns true if the string s is a number }
    function Is_Number(const S : string) : Boolean;{$ifdef USEINLINE}inline;{$endif}
    {# Returns true if value is a power of 2, the actual
       exponent value is returned in power.
    }
    function IsPowerOf2(Value : Int64;out Power : LongInt) : Boolean;
    function IsPowerOf2(const Value : TConstExprInt;out Power : LongInt) : Boolean;
    {# Returns true if abs(value) is a power of 2, the actual
       exponent value is returned in power.
    }
    function IsAbsPowerOf2(const Value : TConstExprInt; out Power : LongInt) : Boolean;
    { # Returns the power of 2 >= value }
    function NextPowerOf2(Value : QWord; out Power: LongInt) : QWord;

    function Backspace_Quote(const S:string;const QChars:TCharSet):string;
    function Octal_Quote(const S:string;const QChars:TCharSet):string;

    {# If the string is quoted, in accordance with pascal, it is
       dequoted and returned in s, and the function returns true.
       If it is not quoted, or if the quoting is bad, s is not touched,
       and false is returned.
    }
    function DePascalQuote(var S: AnsiString): Boolean;
    function CompareStr(const S1, S2: ShortString): Integer;
    function CompareText(S1, S2: ShortString): Integer;

    { releases the string p and assigns nil to p  }
    { if p=nil then freemem isn't called          }
    procedure StringDispose(var P : PShortString);{$ifdef USEINLINE}inline;{$endif}


    { allocates mem for a copy of s, copies s to this mem and returns }
    { a pointer to this mem                                           }
    function StringDup(const S : ShortString) : PShortString;{$ifdef USEINLINE}inline;{$endif}
    function StringDup(const S : AnsiString) : PShortString;{$ifdef USEINLINE}inline;{$endif}

    {# Allocates memory for the string @var(s) and copies s as zero
       terminated string to that allocated memory and returns a pointer
       to that mem
    }
    function  StrPNew(const S : ShortString) : PChar;
    function  StrPNew(const S : AnsiString) : PChar;

    {# makes the character @var(c) lowercase, with spanish, french and german
       character set
    }
    function LowerCase(C : Char) : Char;

    { allocate a new pchar with the contents of a}
    function AnsiString2PChar(const A: AnsiString) : PChar;

    { Ansistring (pchar+length) support }
    procedure AnsiStringDispose(var P : PChar;Length : LongInt);
    function CompareAnsiStrings(P1,P2 : PChar;Length1,Length2 : LongInt) : LongInt;
    function ConcatAnsiStrings(P1,P2 : PChar;Length1,Length2 : LongInt) : PChar;

    function LengthULEB128(A: QWord) : Byte;
    function LengthSLEB128(A: Int64) : Byte;
    function EncodeULEB128(A: QWord;out Buf;Len: Byte) : Byte;
    function EncodeSLEB128(A: Int64;out Buf;Len: Byte) : Byte;

  { hide Sysutils.ExecuteProcess in units using this one after SysUtils}
  const
    ExecuteProcess = 'Do not use' deprecated 'Use cfileutil.RequotedExecuteProcess instead, ExecuteProcess cannot deal with single quotes as used by Unix command lines';

implementation

    uses
      SysUtils;

    var
      UpperTbl,
      LowerTbl  : array[Char] of Char;


    function Min(A,B : LongInt) : LongInt;{$ifdef USEINLINE}inline;{$endif}
    {
      return the minimal of a and b
    }
      begin
         if A<=B then
           Min:=A
         else
           Min:=B;
      end;


    function Min(A,B : Int64) : Int64;{$ifdef USEINLINE}inline;{$endif}
    {
      return the minimal of a and b
    }
      begin
         if A<=B then
           Min:=A
         else
           Min:=B;
      end;


    function Min(const A,B : TConstExprInt) : TConstExprInt;{$ifdef USEINLINE}inline;{$endif}
    {
      return the minimal of a and b
    }
      begin
         if A<=B then
           Min:=A
         else
           Min:=B;
      end;


    function Min(A,B : QWord) : QWord;
    {
      return the minimal of a and b
    }
      begin
         if A<=B then
           Min:=A
         else
           Min:=B;
      end;


    function Max(A,B : LongInt) : LongInt;{$ifdef USEINLINE}inline;{$endif}
    {
      return the maximum of a and b
    }
      begin
         if A>=B then
           Max:=A
         else
           Max:=B;
      end;


    function Max(A,B : Int64) : Int64;{$ifdef USEINLINE}inline;{$endif}
    {
      return the maximum of a and b
    }
      begin
         if A>=B then
           Max:=A
         else
           Max:=B;
      end;


    function Max(A,B : QWord) : QWord;{$ifdef USEINLINE}inline;{$endif}
    {
      return the maximum of a and b
    }
      begin
         if A>=B then
           Max:=A
         else
           Max:=B;
      end;


    function Max(const A,B : TConstExprInt) : TConstExprInt;{$ifdef USEINLINE}inline;{$endif}
    {
      return the maximum of a and b
    }
      begin
         if A>=B then
           Max:=A
         else
           Max:=B;
      end;


    function NewAlignment(OldAlignment: LongInt; Offset: Int64): LongInt;
      begin
        { oldalignment must be power of two.

          Negating two's complement number keeps its tail '100...000' and complements all bits above.
          "x and -x" extracts this tail of 'x'.
          Said tail of "oldalignment or offset" is the desired answer. }

        Result:=OldAlignment or LongInt(Offset); { high part of offset won't matter as long as alignment is 32-bit }
        Result:=Result and -Result;
      end;


    function Reverse_Byte(B: Byte): Byte;
      const
        ReverseNibble:array[0..15] of 0..15 =
          (%0000,%1000,%0100,%1100,%0010,%1010,%0110,%1110,
           %0001,%1001,%0101,%1101,%0011,%1011,%0111,%1111);
      begin
        Reverse_Byte:=(ReverseNibble[B and $f] shl 4) or ReverseNibble[B shr 4];
      end;

    function Reverse_Word(W: Word): Word;
      type
        TWordRec = packed record
          HI, LO: Byte;
        end;

      begin
        TWordRec(Reverse_Word).HI := Reverse_Byte(TWordRec(W).LO);
        TWordRec(Reverse_Word).LO := Reverse_Byte(TWordRec(W).HI);
      end;


    function Reverse_LongWord(L: LongWord): LongWord;
      type
        TLongWordRec = packed record
          B: array[0..3] of Byte;
        end;

      begin
        TLongWordRec(Reverse_LongWord).B[0] := Reverse_Byte(TLongWordRec(L).B[3]);
        TLongWordRec(Reverse_LongWord).B[1] := Reverse_Byte(TLongWordRec(L).B[2]);
        TLongWordRec(Reverse_LongWord).B[2] := Reverse_Byte(TLongWordRec(L).B[1]);
        TLongWordRec(Reverse_LongWord).B[3] := Reverse_Byte(TLongWordRec(L).B[0]);
      end;


    function Align(I,A:LongInt):LongInt;{$ifdef USEINLINE}inline;{$endif}
    {
      return value <i> aligned <a> boundary. <a> must be power of two.
    }
      begin
        { One-line formula for i >= 0 is
          >>> (i + a - 1) and not (a - 1),
          and for i < 0 is
          >>> i and not (a - 1). }

        if A>0 then
          A:=A-1; { 'a' is decremented beforehand, this also allows a=0 as a synonym for a=1. }
        if I>=0 then
          I:=I+A;
        Result:=I and not A;
      end;


    function Align(I,A:Int64):Int64;{$ifdef USEINLINE}inline;{$endif}
    {
      return value <i> aligned <a> boundary. <a> must be power of two.
    }
      begin
        { Copy of 'longint' version. }
        if A>0 then
          A:=A-1;
        if I>=0 then
          I:=I+A;
        Result:=I and not A;
      end;


    function Align(I,A:QWord):QWord;{$ifdef USEINLINE}inline;{$endif}
    {
      return value <i> aligned <a> boundary. <a> must be power of two.
    }
      begin
        { No i < 0 case here. }
        if A>0 then
          A:=A-1;
        Result:=(I+A) and not A;
      end;


    function PackedBitsLoadSize(BitLen: Int64) : Int64;
      begin
         case BitLen of
           1,2,4,8:
             Result := 1;
           { 10 bits can never be split over 3 bytes via 1-8-1, because it }
           { always starts at a multiple of 10 bits. Same for the others.  }
           3,5,6,7,9,10,12,16:
             Result := 2;
  {$ifdef cpu64bitalu}
           { performance penalty for unaligned 8 byte access is much   }
           { higher than for unaligned 4 byte access, at least on ppc, }
           { so use 4 bytes even in some cases where a value could     }
           { always loaded using a single 8 byte load (e.g. in case of }
           { 28 bit values)                                            }
           11,13,14,15,17..32:
             Result := 4;
           else
             Result := 8;
  {$else cpu64bitalu}
           else
             Result := 4;
  {$endif cpu64bitalu}
         end;
      end;


    function IsBetterAlignedThan(New, Org, Limit: Cardinal): Boolean;
      var
        Cnt: Cardinal;
      begin
        Cnt:=2;
        while (Cnt <= Limit) do
          begin
            if (Org and (Cnt-1)) > (New and (Cnt-1)) then
              begin
                Result:=True;
                Exit;
              end
            else if (Org and (Cnt-1)) < (New and (Cnt-1)) then
              begin
                Result:=False;
                Exit;
              end;
            Cnt:=Cnt*2;
          end;
        Result:=False;
      end;


    function Next_Prime(L: LongInt): LongInt;
      var
        Check, CheckBound: LongInt;
        Ok: Boolean;
      begin
        Result:=L or 1;
        while L<High(LongInt) do
          begin
            Ok:=True;
            CheckBound:=Trunc(Sqrt(L));
            Check:=3;
            while Check<CheckBound do
              begin
                if (L mod Check) = 0 then
                  begin
                    Ok:=False;
                    Break;
                  end;
                Inc(Check,2);
              end;
            if Ok then
              Exit;
            Inc(L);
          end;
      end;


    function Used_Align(VarAlign,MinAlign,MaxAlign:LongInt):LongInt;
      begin
        { varalign  : minimum alignment required for the variable
          minalign  : Minimum alignment of this structure, 0 = undefined
          maxalign  : Maximum alignment of this structure, 0 = undefined }
        if (MinAlign>0) and
           (VarAlign<=MinAlign) then
         Used_Align:=MinAlign
        else
         begin
           if (MaxAlign>0) and
              (VarAlign>MaxAlign) then
            Used_Align:=MaxAlign
           else
            Used_Align:=VarAlign;
         end;
      end;


    procedure Replace(var S:ShortString;S1:ShortString;const S2:ShortString);
      var
         Last,
         I  : LongInt;
      begin
        S1:=Upper(S1);
        Last:=0;
        repeat
          I:=Pos(S1,Upper(S));
          if I=Last then
           I:=0;
          if (I>0) then
           begin
             Delete(S,I,Length(S1));
             Insert(S2,S,I);
             Last:=I;
           end;
        until (I=0);
      end;


    procedure Replace(var S:AnsiString;S1:ShortString;const S2:AnsiString);
      var
         Last,
         I  : LongInt;
      begin
        S1:=Upper(S1);
        Last:=0;
        repeat
          I:=Pos(S1,Upper(S));
          if I=Last then
           I:=0;
          if (I>0) then
           begin
             Delete(S,I,Length(S1));
             Insert(S2,S,I);
             Last:=I;
           end;
        until (I=0);
      end;


    procedure ReplaceCase(var S:ShortString;const S1,S2:ShortString);
      var
         Last,
         I  : LongInt;
      begin
        Last:=0;
        repeat
          I:=Pos(S1,S);
          if I=Last then
           I:=0;
          if (I>0) then
           begin
             Delete(S,I,Length(S1));
             Insert(S2,S,I);
             Last:=I;
           end;
        until (I=0);
      end;


    procedure ReplaceCase(var S: AnsiString; const S1, S2: AnsiString);
      var
         Last,
         I  : LongInt;
      begin
        Last:=0;
        repeat
          I:=Pos(S1,S);
          if I=Last then
           I:=0;
          if (I>0) then
           begin
             Delete(S,I,Length(S1));
             Insert(S2,S,I);
             Last:=I;
           end;
        until (I=0);
      end;


    Function MatchPattern(const Pattern,What:string):Boolean;
      var
        Found : Boolean;
        I1,I2 : LongInt;
      begin
        I1:=0;
        I2:=0;
        if Pattern='' then
          begin
            Result:=(What='');
            Exit;
          end;
        Found:=True;
        repeat
          Inc(I1);
          if (I1>Length(Pattern)) then
            Break;
          Inc(I2);
          if (I2>Length(What)) then
            Break;
          case Pattern[I1] of
            '?' :
              Found:=True;
            '*' :
              begin
                Found:=True;
                if (I1=Length(Pattern)) then
                 I2:=Length(What)
                else
                 if (I1<Length(Pattern)) and (Pattern[I1+1]<>What[I2]) then
                  begin
                    if I2<Length(What) then
                     Dec(I1)
                  end
                else
                 if I2>1 then
                  Dec(I2);
              end;
            else
              Found:=(Pattern[I1]=What[I2]) or (What[I2]='?');
          end;
        until not Found;
        if Found then
          begin
            Found:=(I2>=Length(What)) and
                   (
                    (I1>Length(Pattern)) or
                    ((I1=Length(Pattern)) and
                     (Pattern[I1]='*'))
                   );
          end;
        Result:=Found;
      end;


    function Upper(const C : Char) : Char;
    {
      return uppercase of c
    }
      begin
        Upper:=UpperTbl[C];
      end;


    function Upper(const S : ShortString) : ShortString;
    {
      return uppercased string of s
    }
      var
        I  : LongInt;
      begin
        for I:=1 to Length(S) do
          Upper[I]:=UpperTbl[S[I]];
        Upper[0]:=S[0];
      end;


    function Upper(const S : AnsiString) : AnsiString;
    {
      return uppercased string of s
    }
      var
        I,N : SizeInt;
      begin
        Result:=S;
        N:=Length(S);
        I:=0;
        while I<N do
          if PChar(Pointer(S))[I] in ['a'..'z'] then
            begin
              UniqueString(Result);
              repeat
                PChar(Pointer(Result))[I]:=UpperTbl[PChar(Pointer(S))[I]];
                Inc(I);
              until I=N;
              Exit;
            end
          else
            Inc(I);
      end;


    function Lower(const C : Char) : Char;
    {
      return lowercase of c
    }
      begin
        Lower:=LowerTbl[C];
      end;


    function Lower(const S : ShortString) : ShortString;
    {
      return lowercased string of s
    }
      var
        I : LongInt;
      begin
        for I:=1 to Length(S) do
          Lower[I]:=LowerTbl[S[I]];
        Lower[0]:=S[0];
      end;


    function Lower(const S : AnsiString) : AnsiString;
    {
      return lowercased string of s
    }
      var
        I,N : SizeInt;
      begin
        Result:=S;
        N:=Length(S);
        I:=0;
        while I<N do
          if PChar(Pointer(S))[I] in ['A'..'Z'] then
            begin
              UniqueString(Result);
              repeat
                PChar(Pointer(Result))[I]:=LowerTbl[PChar(Pointer(S))[I]];
                Inc(I);
              until I=N;
              Exit;
            end
          else
            Inc(I);
      end;


    procedure UpperVar(var S : ShortString);
    {
      uppercase string s
    }
      var
         I : LongInt;
      begin
         for I:=1 to Length(S) do
          S[I]:=UpperTbl[S[I]];
      end;


    procedure InitUpperLower;
      var
        C : Char;
      begin
        for C:=#0 to #255 do
         begin
           LowerTbl[C]:=C;
           UpperTbl[C]:=C;
           case C of
             'A'..'Z' :
               LowerTbl[C]:=Char(Byte(C)+32);
             'a'..'z' :
               UpperTbl[C]:=Char(Byte(C)-32);
           end;
         end;
      end;


    function DStr(L:LongInt):string;
      var
        TmpStr : string[32];
        I : LongInt;
      begin
        Str(L,TmpStr);
        I:=Length(TmpStr);
        while (I>3) do
         begin
           Dec(I,3);
           if TmpStr[I]<>'-' then
            Insert('.',TmpStr,I+1);
         end;
        DStr:=TmpStr;
      end;


    function RPos(const Needle: Char; const Haystack: ShortString): LongInt;
      begin
        Result:=Length(Haystack);
        while (Result>0) do
          begin
            if Haystack[Result]=Needle then
              Exit;
            Dec(Result);
          end;
      end;


    function RPos(const Needle: ShortString; const Haystack: ShortString): LongInt;
      begin
        Result:=0;
        if (Length(Needle)=0) or
           (Length(Needle)>Length(Haystack)) then
          Exit;
        Result:=Length(Haystack)-Length(Needle)+1;
        repeat
          if (Haystack[Result]=Needle[1]) and
             (CompareByte(Haystack[Result],Needle[1],Length(Needle))=0) then
            Exit;
          Dec(Result);
        until Result=0;
      end;


    function TrimSpace(const S:ShortString):ShortString;
    {
      return s with all leading and ending spaces and tabs removed
    }
      var
        I,J : LongInt;
      begin
        I:=Length(S);
        while (I>0) and (S[I] in [#9,' ']) do
         Dec(I);
        J:=1;
        while (J<I) and (S[J] in [#9,' ']) do
         Inc(J);
        TrimSpace:=Copy(S,J,I-J+1);
      end;


    function TrimSpace(const S:AnsiString):AnsiString;
    {
      return s with all leading and ending spaces and tabs removed
    }
      var
        I,J : LongInt;
      begin
        I:=Length(S);
        while (I>0) and (S[I] in [#9,' ']) do
         Dec(I);
        J:=1;
        while (J<I) and (S[J] in [#9,' ']) do
         Inc(J);
        TrimSpace:=Copy(S,J,I-J+1);
      end;


    function Space (B : LongInt): ShortString;
      var
       S: ShortString;
      begin
        Space[0] := Chr(B);
        S[0] := Chr(B);
        FillChar (S[1],B,' ');
        Space:=S;
      end;


    function PadSpace(const S:ShortString;Len:LongInt):ShortString;
    {
      return s with spaces add to the end
    }
      begin
         if Length(S)<Len then
          PadSpace:=S+Space(Len-Length(S))
         else
          PadSpace:=S;
      end;


    function PadSpace(const S:AnsiString;Len:LongInt):AnsiString;
    {
      return s with spaces add to the end
    }
      begin
         if Length(S)<Len then
          PadSpace:=S+Space(Len-Length(S))
         else
          PadSpace:=S;
      end;


    function GetToken(var S:ShortString;EndChar:Char):ShortString;
      var
        I : LongInt;
        Quote : Char;
      begin
        GetToken:='';
        S:=TrimSpace(S);
        if (Length(S)>0) and
           (S[1] in ['''','"']) then
         begin
           Quote:=S[1];
           I:=1;
           while (I<Length(S)) do
            begin
              Inc(I);
              if S[I]=Quote then
               begin
                 { Remove double quote }
                 if (I<Length(S)) and
                    (S[I+1]=Quote) then
                  begin
                    Delete(S,I,1);
                    Inc(I);
                  end
                 else
                  begin
                    GetToken:=Copy(S,2,I-2);
                    Delete(S,1,I);
                    Exit;
                  end;
               end;
            end;
           GetToken:=S;
           S:='';
         end
        else
         begin
           I:=Pos(EndChar,S);
           if I=0 then
            begin
              GetToken:=S;
              S:='';
              Exit;
            end
           else
            begin
              GetToken:=Copy(S,1,I-1);
              Delete(S,1,I);
              Exit;
            end;
         end;
      end;


    function GetToken(var S:AnsiString;EndChar:Char):AnsiString;
      var
        I : LongInt;
        Quote : Char;
      begin
        GetToken:='';
        S:=TrimSpace(S);
        if (Length(S)>0) and
           (S[1] in ['''','"']) then
         begin
           Quote:=S[1];
           I:=1;
           while (I<Length(S)) do
            begin
              Inc(I);
              if S[I]=Quote then
               begin
                 { Remove double quote }
                 if (I<Length(S)) and
                    (S[I+1]=Quote) then
                  begin
                    Delete(S,I,1);
                    Inc(I);
                  end
                 else
                  begin
                    GetToken:=Copy(S,2,I-2);
                    Delete(S,1,I);
                    Exit;
                  end;
               end;
            end;
           GetToken:=S;
           S:='';
         end
        else
         begin
           I:=Pos(EndChar,S);
           if I=0 then
            begin
              GetToken:=S;
              S:='';
              Exit;
            end
           else
            begin
              GetToken:=Copy(S,1,I-1);
              Delete(S,1,I);
              Exit;
            end;
         end;
      end;


   function RealToStr(E:BestReal):string;{$ifdef USEINLINE}inline;{$endif}
     begin
        Str(E,Result);
     end;


   function ToStr(I : QWord) : string;{$ifdef USEINLINE}inline;{$endif}overload;
   {
     return string of value i
   }
     begin
        Str(I,Result);
     end;


   function ToStr(I : Int64) : string;{$ifdef USEINLINE}inline;{$endif}overload;
   {
     return string of value i
   }
     begin
        Str(I,Result);
     end;


   function ToStr(I : LongInt) : string;{$ifdef USEINLINE}inline;{$endif}overload;
   {
     return string of value i
   }
     begin
        Str(I,Result);
     end;


   function ToStr_With_Plus(I : Int64) : string;{$ifdef USEINLINE}inline;{$endif}
   {
     return string of value i, but always include a + when i>=0
   }
     begin
        Str(I,Result);
        if I>=0 then
          Result:='+'+Result;
     end;


    function Is_Number(const S : string) : Boolean;{$ifdef USEINLINE}inline;{$endif}
    {
      is string a correct number ?
    }
      var
         W : Integer;
         L : LongInt;
      begin
         Val(S,L,W);
         // remove warning
         L:=L;
         Is_Number:=(W=0);
      end;


    function IsPowerOf2(Value : Int64;out Power : LongInt) : Boolean;
    {
      return if value is a power of 2. And if correct return the power
    }
      begin
        if (Value <= 0) or (Value and (Value - 1) <> 0) then
          Exit(False);
        Power:=BsfQWord(Value);
        Result:=True;
      end;


    function IsPowerOf2(const Value: TConstExprInt; out Power: LongInt): Boolean;
      begin
        if Value.Signed or
           (Value.UValue<=High(Int64)) then
          Result:=IsPowerOf2(Value.SValue,Power)
        else if not Value.Signed and
            (Value.SValue=Low(Int64)) then
          begin
            Result:=True;
            Power:=63;
          end
        else
          Result:=False;
      end;


    function IsAbsPowerOf2(const Value : TConstExprInt;out Power : LongInt) : Boolean;
      begin
        if IsPowerOf2(Value,Power) then
          Result:=True
        else if Value.Signed and (Value.SValue<0) and (Value.SValue<>Low(Int64)) and IsPowerOf2(-Value.SValue,Power) then
          Result:=True
        else
          Result:=False;
      end;


    function NextPowerOf2(Value : QWord; out Power: LongInt) : QWord;
      begin
        Power:=-1;
        Result:=0;
        if (Value=0) or (Value>QWord($8000000000000000)) then
          Exit;

        Power:=BsrQWord(Value);
        Result:=QWord(1) shl Power;
        if (Value and (Value-1))<>0 then
          begin
            Inc(Power);
            Result:=Result shl 1;
          end;
      end;


    function Backspace_Quote(const S:string;const QChars:TCharSet):string;

    var I:Byte;

    begin
      Backspace_Quote:='';
      for I:=1 to Length(S) do
        begin
          if (S[I]=#10) and (#10 in QChars) then
            Backspace_Quote:=Backspace_Quote+'\n'
          else if (S[I]=#13) and (#13 in QChars) then
            Backspace_Quote:=Backspace_Quote+'\r'
          else
            begin
              if S[I] in QChars then
                Backspace_Quote:=Backspace_Quote+'\';
              Backspace_Quote:=Backspace_Quote+S[I];
            end;
        end;
    end;


    function Octal_Quote(const S:string;const QChars:TCharSet):string;

    var I:Byte;

    begin
      Octal_Quote:='';
      for I:=1 to Length(S) do
        begin
          if S[I] in QChars then
            begin
              if Ord(S[I])<64 then
                Octal_Quote:=Octal_Quote+'\'+OctStr(Ord(S[I]),3)
              else
                Octal_Quote:=Octal_Quote+'\'+OctStr(Ord(S[I]),4);
            end
          else
            Octal_Quote:=Octal_Quote+S[I];
        end;
    end;


    function DePascalQuote(var S: AnsiString): Boolean;
      var
        DestPos, SourcePos, Len: Integer;
        T: string;
        CH: Char;
    begin
      T:='';
      DePascalQuote:= False;
      Len:= Length(S);
      if (Len >= 1) and (S[1] = '''') then
        begin
          {Remove quotes, exchange '' against ' }
          DestPos := 0;
          SourcePos:=1;
          while (SourcePos<Len) do
            begin
              Inc(SourcePos);
              CH := S[SourcePos];
              if CH = '''' then
                begin
                  Inc(SourcePos);
                  if (SourcePos <= Len) and (S[SourcePos] = '''') then
                    {Add the quote as part of string}
                  else
                    begin
                      SetLength(T, DestPos);
                      S:= T;
                      Exit(True);
                    end;
                end;
              Inc(DestPos);
              T[DestPos] := CH;
            end;
        end;
    end;


    function AnsiString2PChar(const A: AnsiString) : PChar;
      var
        Len: PtrInt;
      begin
        Len:=Length(A);
        GetMem(Result,Len+1);
        if (Len<>0) then
          Move(A[1],Result[0],Len);
        Result[Len]:=#0;
      end;


    function LowerCase(C : Char) : Char;
       begin
          case C of
             #65..#90 : C := Chr(Ord (C) + 32);
             #154 : C:=#129;  { german }
             #142 : C:=#132;  { german }
             #153 : C:=#148;  { german }
             #144 : C:=#130;  { french }
             #128 : C:=#135;  { french }
             #143 : C:=#134;  { swedish/norge (?) }
             #165 : C:=#164;  { spanish }
             #228 : C:=#229;  { greek }
             #226 : C:=#231;  { greek }
             #232 : C:=#227;  { greek }
          end;
          LowerCase := C;
       end;


    function StrPNew(const S : ShortString) : PChar;
      var
         P : PChar;
      begin
         GetMem(P,Length(S)+1);
         Move(S[1],P^,Length(S));
         P[Length(S)]:=#0;
         Result:=P;
      end;

    function StrPNew(const S: AnsiString): PChar;
      var
         P : PChar;
      begin
        GetMem(P,Length(S)+1);
        Move(S[1],P^,Length(S)+1);
        Result:=P;
      end;


    procedure StringDispose(var P : PShortString);{$ifdef USEINLINE}inline;{$endif}
      begin
         if Assigned(P) then
           begin
             FreeMem(P);
             P:=nil;
           end;
      end;


    function StringDup(const S : ShortString) : PShortString;{$ifdef USEINLINE}inline;{$endif}
      begin
         GetMem(Result,Length(S)+1);
         Result^:=S;
      end;


    function StringDup(const S : AnsiString) : PShortString;{$ifdef USEINLINE}inline;{$endif}
      begin
         GetMem(Result,Length(S)+1);
         Result^:=S;
      end;


    function PosCharset(const CS : TCharSet;const S : AnsiString) : Integer;
      var
        I : Integer;
      begin
        Result:=0;
        for I:=1 to Length(S) do
          if S[I] in CS then
            begin
              Result:=I;
              Exit;
            end;
      end;


    function CompareStr(const S1, S2: ShortString): Integer;
      var
        Count, Count1, Count2: Integer;
      begin
        Count1 := Length(S1);
        Count2 := Length(S2);
        if Count1>Count2 then
          Count:=Count2
        else
          Count:=Count1;
        Result := CompareByte(S1[1],S2[1], Count);
        if Result=0 then
          Result:=Count1-Count2;
      end;


    function CompareText(S1, S2: ShortString): Integer;
      begin
        UpperVar(S1);
        UpperVar(S2);
        Result:=CompareStr(S1,S2);
      end;


{*****************************************************************************
                               Ansistring (PChar+Length)
*****************************************************************************}

    procedure AnsiStringDispose(var P : PChar;Length : LongInt);
      begin
         if Assigned(P) then
           begin
             FreeMem(P);
             P:=nil;
           end;
      end;


    { enable ansistring comparison }
    { 0 means equal }
    { 1 means p1 > p2 }
    { -1 means p1 < p2 }
    function CompareAnsiStrings(P1,P2 : PChar;Length1,Length2 :  LongInt) : LongInt;
      var
         Cmp : SizeInt;
      begin
         Cmp:=CompareByte(P1^,P2^,Min(Length1,Length2));
         if Cmp=0 then
           Cmp:=Length1-Length2;
         Result:=Ord(Cmp>0)-Ord(Cmp<0);
      end;


    function ConcatAnsiStrings(P1,P2 : PChar;Length1,Length2 : LongInt) : PChar;
      var
         P : PChar;
      begin
         GetMem(P,Length1+Length2+1);
         Move(P1[0],P[0],Length1);
         Move(P2[0],P[Length1],Length2+1);
         ConcatAnsiStrings:=P;
      end;


    procedure DefaultError(I:LongInt);
      begin
        WriteLn('Internal error ',I);
        RunError(255);
      end;


    function LengthULEB128(A: QWord) : Byte;
      begin
        Result:=0;
        repeat
          Inc(Result);
          A := A shr 7;
        until A=0;
      end;


    function LengthSLEB128(A: Int64) : Byte;
      begin
        { 'a xor SarInt64(a,63)' has upper bits 0...01 where '0's symbolize sign bits of 'a' and 1 symbolizes its most significant non-sign bit.
          'shl 1' ensures storing the sign bit. }
        Result:=LengthULEB128(QWord(A xor SarInt64(A,63)) shl 1);
      end;


    function EncodeULEB128(A: QWord;out Buf;Len : Byte) : Byte;
      var
        B: Byte;
        PBuf : PByte;
      begin
        Result:=0;
        PBuf:=@Buf;
        repeat
          B := A and $7f;
          A := A shr 7;
          if A<>0 then
            B := B or $80;
          PBuf^:=B;
          Inc(PBuf);
          Inc(Result);
        until (A=0) and (Result>=Len);
      end;


    function EncodeSLEB128(A: Int64;out Buf;Len : Byte) : Byte;
      var
        B: Byte;
        More: Boolean;
        PBuf : PByte;
      begin
        Result:=0;
        PBuf:=@Buf;
        repeat
          B := A and $7f;
          A := SarInt64(A, 7);
          Inc(Result);
          More:=(Result<Len) or (A<>-(B shr 6));
          PBuf^:=B or Byte(More) shl 7;
          Inc(PBuf);
        until not More;
      end;


initialization
  InternalErrorProc:=@DefaultError;
  InitUpperLower;
end.
