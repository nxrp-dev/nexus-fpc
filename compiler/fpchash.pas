{
    Copyright (c) 2000-2002 by Free Pascal Development Team

    Routines to compute hash values

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
Unit fpchash;

{$i fpcdefs.inc}

Interface

Function UpdateCRC32(InitCRC:Cardinal;const InBuf;InLen:Integer):Cardinal;
{ If needed trims the string to maxlen, adding at the end the CRC32 of discarded chars.
  The resulting string is guaranteed to be not longer than maxlen. }
function TrimStrCRC32(const S: AnsiString; MaxLen: LongInt): AnsiString;

{ calculate string hash using FNV Hash:
  http://www.isthe.com/chongo/tech/comp/fnv/
}
function InitFNV64: UInt64;
function UpdateFNV64(const InitFNV: UInt64; const InBuf; InLen: Integer): UInt64;

type
  Base64OfUint64String = string[11];

function Base64Mangle(const X: UInt64): Base64OfUInt64String;

Implementation

{*****************************************************************************
                                   Crc 32
*****************************************************************************}

var
  CRC32Tbl : array[0..255] of Cardinal;

procedure MakeCRC32Tbl;
var
  CRC : Cardinal;
  I,N : Integer;
begin
  for I:=0 to 255 do
   begin
     CRC:=I;
     for N:=1 to 8 do
      if (CRC and 1)<>0 then
       CRC:=(CRC shr 1) xor Cardinal($edb88320)
      else
       CRC:=CRC shr 1;
     CRC32Tbl[I]:=CRC;
   end;
end;


Function UpdateCRC32(InitCRC:Cardinal;const InBuf;InLen:Integer):Cardinal;
var
  I : Integer;
  P : PChar;
begin
  if CRC32Tbl[1]=0 then
   MakeCRC32Tbl;
  P:=@InBuf;
  Result:=not InitCRC;
  for I:=1 to InLen do
   begin
     Result:=CRC32Tbl[Byte(Result) xor Byte(P^)] xor (Result shr 8);
     Inc(P);
   end;
  Result:=not Result;
end;


function TrimStrCRC32(const S: AnsiString; MaxLen: LongInt): AnsiString;
var
  CRC: DWord;
  Len: LongInt;
begin
  Len:=Length(S);
  if (Len<=MaxLen) or (Len<12) then
    Result:=S
  else
   begin
     Dec(MaxLen,11);
     CRC:=0;
     CRC:=UpdateCRC32(CRC,S[MaxLen+1],Len-MaxLen);
     Result:=Copy(S,1,MaxLen)+'$CRC'+HexStr(CRC,8);
   end;
end;


function InitFNV64: UInt64;
  begin
    Result:=UInt64(14695981039346656037);
  end;

{ calculate string hash using FNV Hash:
  http://www.isthe.com/chongo/tech/comp/fnv/
}
{$push} {$rangechecks off} {$overflowchecks off}
function UpdateFNV64(const InitFNV: UInt64; const InBuf; InLen: Integer): UInt64;
const
  M = UInt64(1099511628211);
var
  PP: PByte;
begin
  Result := InitFNV;
  PP := @InBuf;
  while InLen >= 4 do
   begin
     Result := ((((Result xor PP[0]) * M xor PP[1]) * M xor PP[2]) * M xor PP[3]) * M;
     PP := PP + 4;
     InLen := InLen - 4;
   end;
  while InLen > 0 do
   begin
     Result := (Result xor PP^) * M;
     PP := PP + 1;
     InLen := InLen - 1;
   end;
end;
{$pop}

const
  Base64Chars: array[0 .. 63] of Char = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_$';

function Base64Mangle(const X: UInt64): Base64OfUInt64String;
var
  B64Chars: PChar;
begin
  B64Chars := PChar(Base64Chars);
  Result[0] := #11;
  Result[1] := B64Chars[X and $3f];
  Result[2] := B64Chars[UInt32(X) shr 6 and $3f];
  Result[3] := B64Chars[UInt32(X) shr 12 and $3f];
  Result[4] := B64Chars[UInt32(X) shr 18 and $3f];
  Result[5] := B64Chars[UInt32(X) shr 24 and $3f];
  Result[6] := B64Chars[X shr 30 and $3f];
  Result[7] := B64Chars[X shr 36 and $3f];
  Result[8] := B64Chars[X shr 42 and $3f];
  Result[9] := B64Chars[X shr 48 and $3f];
  Result[10] := B64Chars[X shr 54 and $3f];
  Result[11] := B64Chars[X shr 60];
end;

end.
