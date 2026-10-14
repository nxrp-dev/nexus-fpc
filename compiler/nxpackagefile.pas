(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit nxpackagefile;

{$mode objfpc}{$H+}

interface

uses SysUtils;

const
  NexusPackageLibraryExtension = '.nxpl';
  NexusPackageMetadataSection = '.nxmeta';
  NexusPackageEnvelopeSize = 40;

{ The envelope is shared by the image section and the sidecar. The image always
  carries the digest, including when its payload is stored in a sidecar. }
function EncodePackageMetadata(const AData: TBytes): TBytes;
function DecodePackageMetadata(const AEnvelope: TBytes): TBytes;
function PackageMetadataReference(const AEnvelope: TBytes): TBytes;
function ReadPackageMetadata(const AImageName: string): TBytes;
function ReadPackageBytes(const AFileName: string): TBytes;
procedure WritePackageBytes(const AFileName: string; const AData: TBytes);

implementation

uses zbase, zcompres, zinflate, sha1;

const
  cMagic = 'NXPM0001';

procedure Invalid(const AReason: string);
begin
  raise Exception.Create('Invalid Nexus package metadata: ' + AReason);
end;

procedure CheckRange(const AData: TBytes; AOffset, ASize: QWord);
begin
  if (AOffset > QWord(Length(AData))) or
     (ASize > QWord(Length(AData)) - AOffset) then
    Invalid('truncated or out-of-bounds data');
end;

function Number(const AData: TBytes; AOffset: QWord; ASize: Byte): QWord;
var
  lIndex: Integer;
begin
  CheckRange(AData, AOffset, ASize);
  Result := 0;
  for lIndex := 0 to ASize - 1 do
    Result := Result or (QWord(AData[AOffset + QWord(lIndex)]) shl (lIndex * 8));
end;

procedure PutNumber(var AData: TBytes; AOffset: Integer; AValue: Cardinal);
var
  lIndex: Integer;
begin
  for lIndex := 0 to 3 do
    AData[AOffset + lIndex] := Byte(AValue shr (lIndex * 8));
end;

function IsText(const AData: TBytes; AOffset: QWord; const AText: string): Boolean;
var
  lIndex: Integer;
begin
  CheckRange(AData, AOffset, Length(AText));
  for lIndex := 1 to Length(AText) do
    if AData[AOffset + QWord(lIndex - 1)] <> Ord(AText[lIndex]) then Exit(False);
  Result := True;
end;

procedure CheckHeader(const AData: TBytes);
begin
  CheckRange(AData, 0, NexusPackageEnvelopeSize);
  if not IsText(AData, 0, cMagic) then Invalid('unsupported storage format');
  if Number(AData, 8, 4) > 1 then Invalid('invalid storage mode');
  if (Number(AData, 12, 4) < 32) or
     (Number(AData, 12, 4) > High(LongInt)) or
     (Number(AData, 16, 4) < 8) or
     (Number(AData, 16, 4) > High(LongInt) - NexusPackageEnvelopeSize) then
    Invalid('invalid metadata size');
end;

function EncodePackageMetadata(const AData: TBytes): TBytes;
var
  lSize: Cardinal;
  lDigest: TSHA1Digest;
begin
  Result := nil;
  if (Length(AData) < 32) or (Length(AData) > High(LongInt) div 2) then
    Invalid('metadata size cannot be encoded');
  lSize := Length(AData) + Length(AData) div 1000 + 64;
  SetLength(Result, NexusPackageEnvelopeSize + lSize);
  Move(cMagic[1], Result[0], Length(cMagic));
  PutNumber(Result, 8, 1);
  PutNumber(Result, 12, Length(AData));
  if compress2(@Result[NexusPackageEnvelopeSize], lSize, AData,
    Length(AData), Z_DEFAULT_COMPRESSION) <> Z_OK then
    Invalid('compression failed');
  PutNumber(Result, 16, lSize);
  lDigest := SHA1Buffer(AData[0], Length(AData));
  Move(lDigest[0], Result[20], SizeOf(lDigest));
  SetLength(Result, NexusPackageEnvelopeSize + lSize);
end;

function DecodePackageMetadata(const AEnvelope: TBytes): TBytes;
var
  lStream: z_stream;
  lDigest: TSHA1Digest;
  lCode: Integer;
begin
  Result := nil;
  CheckHeader(AEnvelope);
  if Number(AEnvelope, 8, 4) <> 1 then Invalid('metadata payload is absent');
  if Number(AEnvelope, 16, 4) <> QWord(Length(AEnvelope) - NexusPackageEnvelopeSize) then
    Invalid('compressed size does not match payload');
  FillChar(lStream, SizeOf(lStream), 0);
  lStream.next_in := @AEnvelope[NexusPackageEnvelopeSize];
  lStream.avail_in := Length(AEnvelope) - NexusPackageEnvelopeSize;
  SetLength(Result, Number(AEnvelope, 12, 4));
  lStream.next_out := @Result[0];
  lStream.avail_out := Length(Result);
  if inflateInit(lStream) <> Z_OK then Invalid('decompressor initialization failed');
  try
    lCode := inflate(lStream, Z_FINISH);
    if (lCode <> Z_STREAM_END) or (lStream.avail_in <> 0) or
       (lStream.total_out <> Cardinal(Length(Result))) then
      Invalid('corrupt or truncated compressed payload');
  finally
    inflateEnd(lStream);
  end;
  lDigest := SHA1Buffer(Result[0], Length(Result));
  if not CompareMem(@lDigest[0], @AEnvelope[20], SizeOf(lDigest)) then
    Invalid('metadata fingerprint mismatch');
end;

function PackageMetadataReference(const AEnvelope: TBytes): TBytes;
begin
  CheckHeader(AEnvelope);
  Result := System.Copy(AEnvelope, 0, NexusPackageEnvelopeSize);
  PutNumber(Result, 8, 0);
end;

function ReadPackageBytes(const AFileName: string): TBytes;
var
  lHandle: THandle;
  lSize: Int64;
begin
  Result := nil;
  lHandle := FileOpen(AFileName, fmOpenRead or fmShareDenyWrite);
  if lHandle = THandle(-1) then Invalid('cannot open ' + AFileName);
  try
    lSize := FileSeek(lHandle, Int64(0), 2);
    if (lSize < 0) or (lSize > High(LongInt)) then Invalid('unsupported file size');
    SetLength(Result, lSize);
    FileSeek(lHandle, Int64(0), 0);
    if (lSize > 0) and (FileRead(lHandle, Result[0], lSize) <> lSize) then
      Invalid('cannot read ' + AFileName);
  finally
    FileClose(lHandle);
  end;
end;

procedure WritePackageBytes(const AFileName: string; const AData: TBytes);
var
  lHandle: THandle;
begin
  lHandle := FileCreate(AFileName);
  if lHandle = THandle(-1) then Invalid('cannot create ' + AFileName);
  try
    if (Length(AData) > 0) and
       (FileWrite(lHandle, AData[0], Length(AData)) <> Length(AData)) then
      Invalid('cannot write ' + AFileName);
  finally
    FileClose(lHandle);
  end;
end;

function ImageMetadata(const AData: TBytes): TBytes;
var
  lTable, lCount, lStride, lNames, lNamesSize, lName, lSection: QWord;
  lOffset, lSize, lPE: QWord;
  lIndex: LongInt;
  lFound, lPEImage: Boolean;
begin
  Result := nil;
  lNames := 0;
  lNamesSize := 0;
  lPEImage := IsText(AData, 0, 'MZ');
  if lPEImage then
  begin
    lPE := Number(AData, 60, 4);
    if (Number(AData, lPE, 4) <> $4550) or
       (Number(AData, lPE + 4, 2) <> $8664) then Invalid('unsupported PE image');
    lCount := Number(AData, lPE + 6, 2);
    lStride := 40;
    lTable := lPE + 24 + Number(AData, lPE + 20, 2);
  end
  else
  begin
    if not IsText(AData, 0, #127'ELF') or (Number(AData, 4, 1) <> 2) or
       (Number(AData, 5, 1) <> 1) or (Number(AData, 18, 2) <> 62) then
      Invalid('unsupported ELF image');
    lTable := Number(AData, 40, 8);
    lStride := Number(AData, 58, 2);
    lCount := Number(AData, 60, 2);
    lIndex := Number(AData, 62, 2);
    if (lStride <> 64) or (lIndex >= lCount) then Invalid('invalid ELF section table');
    CheckRange(AData, lTable, lCount * lStride);
    lNames := Number(AData, lTable + lIndex * lStride + 24, 8);
    lNamesSize := Number(AData, lTable + lIndex * lStride + 32, 8);
    CheckRange(AData, lNames, lNamesSize);
  end;
  if lCount = 0 then Invalid('missing section table');
  CheckRange(AData, lTable, lCount * lStride);
  lFound := False;
  for lIndex := 0 to LongInt(lCount) - 1 do
  begin
    lSection := lTable + lIndex * lStride;
    if lPEImage then
    begin
      if not IsText(AData, lSection, NexusPackageMetadataSection + #0) then Continue;
      lOffset := Number(AData, lSection + 20, 4);
      lSize := Number(AData, lSection + 16, 4);
    end
    else
    begin
      lName := Number(AData, lSection, 4);
      if (lName >= lNamesSize) or
         (Length(NexusPackageMetadataSection) + 1 > lNamesSize - lName) then Continue;
      if not IsText(AData, lNames + lName, NexusPackageMetadataSection + #0) then Continue;
      if Number(AData, lSection + 4, 4) <> 1 then Invalid('invalid metadata section type');
      lOffset := Number(AData, lSection + 24, 8);
      lSize := Number(AData, lSection + 32, 8);
    end;
    if lFound then Invalid('duplicate metadata section');
    lFound := True;
    CheckRange(AData, lOffset, lSize);
    Result := System.Copy(AData, lOffset, lSize);
    CheckHeader(Result);
    lSize := NexusPackageEnvelopeSize;
    if Number(Result, 8, 4) = 1 then Inc(lSize, Number(Result, 16, 4));
    CheckRange(Result, 0, lSize);
    { PE section raw data is rounded to file alignment. }
    SetLength(Result, lSize);
  end;
  if not lFound then Invalid('image has no ' + NexusPackageMetadataSection + ' section');
end;

function ReadPackageMetadata(const AImageName: string): TBytes;
var
  lEnvelope, lSidecar: TBytes;
begin
  lEnvelope := ImageMetadata(ReadPackageBytes(AImageName));
  if Number(lEnvelope, 8, 4) = 0 then
  begin
    lSidecar := ReadPackageBytes(ChangeFileExt(AImageName, '.nxp'));
    CheckHeader(lSidecar);
    if not CompareMem(@lEnvelope[12], @lSidecar[12], NexusPackageEnvelopeSize - 12) then
      Invalid('sidecar does not match package image');
    lEnvelope := lSidecar;
  end;
  Result := DecodePackageMetadata(lEnvelope);
end;

end.
