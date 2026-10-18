{
  This file is part of the Free Component Library.
  Copyright (c) 2021 by the Free Pascal team.

  HOTP and TOTP One-time password algorithms. Compatible with the Google Authenticator.

  See the file COPYING.FPC, included in this distribution,
  for details about the copyright.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

{$IFNDEF FPC_DOTTEDUNITS}
unit onetimepass;
{$ENDIF FPC_DOTTEDUNITS}

{$mode ObjFPC}{$H+}

interface

{$IFDEF FPC_DOTTEDUNITS}
uses
  System.SysUtils , Fcl.BaseNEnc, System.Types, System.DateUtils;
{$ELSE FPC_DOTTEDUNITS}
uses
  SysUtils , basenenc, types, DateUtils;
{$ENDIF FPC_DOTTEDUNITS}

const
  TOTP_Mod = 1000000;
  TOTP_KeyRegeneration = 30; // Time step for TOTP generation. Google Authenticator uses 30 seconds.

Type
  TRandomBytes = Procedure (aBytes : TByteDynArray);

function HOTPCalculateToken(const aSecret: AnsiString; const ACounter: LongInt): LongInt;
function TOTPCalculateToken(const aSecret: AnsiString): LongInt;
function TOTPGenerateToken(const aSecret: AnsiString): LongInt;
function TOTPValidate(const aSecret: AnsiString; const Token: LongInt; const WindowSize: LongInt; var Counter: LongInt): Boolean;
Function TOTPSharedSecret(aRandom : TRandomBytes = Nil) : AnsiString;

implementation

uses HlpHashFactory;

function TOTPCalculateToken(const aSecret: AnsiString): Longint;

begin
  Result:=HOTPCalculateToken(aSecret,-1);
end;

function HOTPCalculateToken(const ASecret: AnsiString; const ACounter: Longint): Longint;
var
  lDigest, lSecret, lTime: TBytes;
  lCounter: Int64;
  lIndex, lOffset: Integer;
  lCode: UInt32;
begin
  lCounter := ACounter;
  if lCounter = -1 then
    lCounter := DateTimeToUnix(Now, False) div TOTP_KeyRegeneration;
  lSecret := Base32.Decode(ASecret);
  SetLength(lTime, 8);
  for lIndex := 0 to 7 do
    lTime[7 - lIndex] := (lCounter shr (8 * lIndex)) and $FF;
  lDigest := THashFactory.THMAC.CreateHMAC(THashFactory.TCrypto.CreateSHA1,
    lSecret).ComputeBytes(lTime).GetBytes;
  lOffset := lDigest[19] and $0F;
  lCode := (UInt32(lDigest[lOffset] and $7F) shl 24) or
    (UInt32(lDigest[lOffset + 1]) shl 16) or
    (UInt32(lDigest[lOffset + 2]) shl 8) or lDigest[lOffset + 3];
  Result := lCode mod TOTP_Mod;
end;

function TOTPGenerateToken(const aSecret: AnsiString): LongInt;
begin
  Result := HOTPCalculateToken(aSecret, -1);
end;

Function TOTPSharedSecret(aRandom : TRandomBytes = Nil) : AnsiString;

var
  RandomKey: TByteDynArray;
  I : Integer;

begin
  RandomKey:=[];
  SetLength(RandomKey,10);
  if aRandom <> Nil then
    aRandom(RandomKey)
  else
    For I:=0 to 9 do
      RandomKey[I]:=Random(256);
  Result:=Base32.Encode(RandomKey);
end;

// @Secret Base32 encoded, @WindowSize=1
function TOTPValidate(const aSecret: AnsiString; const Token: LongInt; const WindowSize: LongInt; var Counter: LongInt): Boolean;
var
  TimeStamp: Longint;
  UnixTime: Longint;
begin
  Result := False;
  UnixTime := DateTimeToUnix(Now,False);
  TimeStamp := UnixTime div TOTP_KeyRegeneration;
  Counter := Timestamp-WindowSize;
  while Counter <= TimeStamp+WindowSize do
  begin
    Result := HOTPCalculateToken(aSecret, Counter) = Token;
    if Result then
      Exit;
    Inc(Counter);
  end;
end;

end.

