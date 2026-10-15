{
    Copyright (c) 2007 by Daniel Mantione

    This unit implements a Tconstexprint type. This type simulates an integer
    type that can handle numbers from low(int64) to high(qword) calculations.

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
unit constexp;

{$i fpcdefs.inc}
{$modeswitch advancedrecords}

interface

uses TPCompilerReal;

type  Tconstexprint=record
        function Is_Negative: Boolean; inline;
        function Extract_Sign_Abs(out Abs: QWord): Boolean;
        procedure Div_Or_Mod(const By: TConstExprInt; IsDiv: Boolean; out R: TConstExprInt);
        function ToBestReal: BestReal;
      var
        Overflow:Boolean;
        case Signed:Boolean of
          False:
            (UValue:QWord);
          True:
            (SValue:Int64);
      end;

operator := (const U:QWord):TConstExprInt;inline;
operator := (const S:Int64):TConstExprInt;inline;
operator := (const C:TConstExprInt):QWord;
operator := (const C:TConstExprInt):Int64;
operator := (const C:TConstExprInt):BestReal;

operator + (const A,B:TConstExprInt):TConstExprInt;
operator - (const A,B:TConstExprInt):TConstExprInt;
operator - (const A:TConstExprInt):TConstExprInt;
operator * (const A,B:TConstExprInt):TConstExprInt;
operator div (const A,B:TConstExprInt):TConstExprInt; inline;
operator mod (const A,B:TConstExprInt):TConstExprInt; inline;
operator / (const A,B:TConstExprInt):BestReal;

operator = (const A,B:TConstExprInt):Boolean;
operator > (const A,B:TConstExprInt):Boolean; inline; { Are reformulated using <. }
operator >= (const A,B:TConstExprInt):Boolean; inline;
operator < (const A,B:TConstExprInt):Boolean;
operator <= (const A,B:TConstExprInt):Boolean; inline;

operator and (const A,B:TConstExprInt):TConstExprInt;
operator or (const A,B:TConstExprInt):TConstExprInt;
operator xor (const A,B:TConstExprInt):TConstExprInt;
operator shl (const A,B:TConstExprInt):TConstExprInt;
operator shr (const A,B:TConstExprInt):TConstExprInt;

function ToStr(const I:TConstExprInt):ShortString;overload;

{****************************************************************************}
implementation
{****************************************************************************}

uses
  CUtils;

function TConstExprInt.Is_Negative: Boolean;
begin
  Result:=Signed and (SValue<0);
end;

{$push} {$q-,r-}
function TConstExprInt.Extract_Sign_Abs(out Abs: QWord): Boolean;
begin
  Result:=Is_Negative;
  if Result then
    Abs:=QWord(-SValue)
  else
    Abs:=UValue;
end;

procedure TConstExprInt.Div_Or_Mod(const By: TConstExprInt; IsDiv: Boolean; out R: TConstExprInt);
var
  AA, BB: QWord;
  NegRes: Boolean;
begin
  if By.UValue=0 then
    begin
      R:=QWord(-Int64(IsDiv)); { Something. All ones if div, all zeros if mod. }
      R.Overflow:=True;
      Exit;
    end;
  { the sign of a modulo operation only depends on the sign of the
    dividend }
  NegRes:=Self.Extract_Sign_Abs(AA) xor By.Extract_Sign_Abs(BB) and IsDiv;
  R.Overflow:=Self.Overflow or By.Overflow;
  if IsDiv then
    R.UValue:=AA div BB
  else
    R.UValue:=AA mod BB;
  R.Signed:=NegRes or (R.SValue>=0);
  if NegRes then
    begin
      R.SValue:=-R.SValue;
      R.Overflow:=R.Overflow or (R.SValue>0); { Strictly > 0! }
    end;
end;
{$pop}

function TConstExprInt.ToBestReal: BestReal;
begin
  if Overflow then
    InternalErrorProc(200706095);
  if Signed then
    Result:=SValue
  else
    Result:=UValue;
end;

operator := (const U:QWord):TConstExprInt;

begin
  Result.Overflow:=False;
  Result.Signed:=False;
  Result.UValue:=U;
end;

operator := (const S:Int64):TConstExprInt;

begin
  Result.Overflow:=False;
  Result.Signed:=True;
  Result.SValue:=S;
end;

operator := (const C:TConstExprInt):QWord;

begin
  if C.Overflow then
    InternalErrorProc(200706091);
  if C.Is_Negative then
    InternalErrorProc(200706092);
  Result:=C.UValue;
end;

operator := (const C:TConstExprInt):Int64;

begin
  if C.Overflow then
    InternalErrorProc(200706093);
  if not C.Signed and (C.SValue<0) then
    InternalErrorProc(200706094);
  Result:=C.SValue;
end;

operator := (const C:TConstExprInt):BestReal;

begin
  if C.Overflow then
    InternalErrorProc(200706095);
  if C.Signed then
    Result:=C.SValue
  else
    Result:=C.UValue;
end;

{$push} {$q-,r-}
operator + (const A,B:TConstExprInt):TConstExprInt;

var ANeg:Boolean;

begin
  Result.Overflow:=A.Overflow or B.Overflow;
  Result.UValue:=A.UValue+B.UValue;
  ANeg:=A.Is_Negative;
  if ANeg<>B.Is_Negative then
    { Negative + positive: cannot overflow, signed if fits (here and below: “fits” means “positive value that fits into svalue”) or if positive operand did fit. }
    Result.Signed:=(Result.SValue>=0) or (A.SValue xor B.SValue<0)
  else if ANeg then
    begin
      { Negative + negative: overflow if positive, always signed. }
      Result.Overflow:=Result.Overflow or (Result.SValue>=0);
      Result.Signed:=True;
    end
  else
    begin
      { Positive + positive: overflow if became less, signed if fits. }
      Result.Overflow:=Result.Overflow or (Result.UValue<A.UValue);
      Result.Signed:=Result.SValue>=0;
    end;
end;

operator - (const A,B:TConstExprInt):TConstExprInt;

var BNeg:Boolean;

begin
  Result.Overflow:=A.Overflow or B.Overflow;
  Result.UValue:=A.UValue-B.UValue;
  BNeg:=B.Is_Negative;
  if A.Is_Negative then
    begin
      { Negative − negative: cannot overflow, always signed.
        Negative - positive: overflow if positive or b did not fit, always signed. }
      Result.Signed:=True;
      if not BNeg then
        Result.Overflow:=Result.Overflow or (B.SValue<0) or (Result.SValue>=0);
    end
  else if BNeg then
    begin
      { Positive - negative: overflow if became less, signed if fits. }
      Result.Overflow:=Result.Overflow or (Result.UValue<A.UValue);
      Result.Signed:=Result.SValue>=0;
    end
  else
    begin
      { Positive − positive: overflow if a < b but result is positive, signed if a < b or fits. }
      Result.Overflow:=Result.Overflow or (A.UValue<B.UValue) and (Result.SValue>=0);
      Result.Signed:=(A.UValue<B.UValue) or (Result.SValue>=0);
    end;
end;

operator - (const A:TConstExprInt):TConstExprInt;

var ANeg:Boolean;

begin
  ANeg:=A.Is_Negative;
  Result.SValue:=-A.SValue;
  Result.Overflow:=A.Overflow or not ANeg and (Result.SValue>0); { Will trigger on > -Low(int64). }
  Result.Signed:=not (ANeg and (A.SValue=Low(A.SValue))); { Unsigned only if negating Low(int64). }
end;

operator * (const A,B:TConstExprInt):TConstExprInt;

var AA,BB:QWord;
    NegRes:Boolean;

begin
  NegRes:=A.Extract_Sign_Abs(AA) xor B.Extract_Sign_Abs(BB);
  Result.UValue:=AA*BB;
  Result.Overflow:=A.Overflow or B.Overflow or
    (Hi(AA) or Hi(BB)<>0) and { Pretest to avoid division in small cases. Must be cheaper than two BsrQWords. }
    (BB<>0) and (High(QWord) div BB<AA);
  Result.Signed:=NegRes or (Result.SValue>=0);
  if NegRes then
    begin
      Result.Overflow:=Result.Overflow or (Result.SValue<0);
      Result.SValue:=-Result.SValue;
    end;
end;
{$pop}

operator div (const A,B:TConstExprInt):TConstExprInt;

begin
  A.Div_Or_Mod(B,True,Result);
end;

operator mod (const A,B:TConstExprInt):TConstExprInt;

begin
  A.Div_Or_Mod(B,False,Result);
end;

operator / (const A,B:TConstExprInt):BestReal;

begin
  Result:=A.ToBestReal/B.ToBestReal;
end;

operator = (const A,B:TConstExprInt):Boolean;

begin
  Result:=(A.UValue=B.UValue) and (A.Is_Negative=B.Is_Negative);
end;

operator > (const A,B:TConstExprInt):Boolean;

begin
  Result:=B<A;
end;

operator >= (const A,B:TConstExprInt):Boolean;

begin
  Result:=not(A<B);
end;

operator < (const A,B:TConstExprInt):Boolean;

begin
  Result:=A.Is_Negative;
  if Result=B.Is_Negative then
    Result:=A.UValue<B.UValue; { Works both with positive < positive and unsigned(negative) < unsigned(negative). }
end;

operator <= (const A,B:TConstExprInt):Boolean;

begin
  Result:=not(B<A);
end;

operator and (const A,B:TConstExprInt):TConstExprInt;

begin
  Result.Overflow:=False;
  Result.Signed:=A.Signed or B.Signed;
  Result.UValue:=A.UValue and B.UValue;
end;

operator or (const A,B:TConstExprInt):TConstExprInt;

begin
  Result.Overflow:=False;
  Result.Signed:=A.Signed or B.Signed;
  Result.UValue:=A.UValue or B.UValue;
end;

operator xor (const A,B:TConstExprInt):TConstExprInt;

begin
  Result.Overflow:=False;
  Result.Signed:=A.Signed or B.Signed;
  Result.UValue:=A.UValue xor B.UValue;
end;

operator shl (const A,B:TConstExprInt):TConstExprInt;

begin
  if B.UValue>=BitSizeOf(A.UValue) then
    Exit(0);
  Result.Overflow:=False;
  Result.Signed:=A.Signed; { signed(1) shl 63 does not fit into signed }
  Result.UValue:=A.UValue shl B.UValue;
end;

operator shr (const A,B:TConstExprInt):TConstExprInt;

begin
  if B.UValue>=BitSizeOf(A.UValue) then
    Exit(0);
  Result.Overflow:=False;
  Result.Signed:=A.Signed;
  Result.UValue:=A.UValue shr B.UValue;
end;

function ToStr(const I:TConstExprInt):ShortString;overload;

begin
  if I.Signed then
    Str(I.SValue,Result)
  else
    Str(I.UValue,Result);
end;

end.
