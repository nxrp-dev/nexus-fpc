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

uses ZBase, ZCompres, ZInflate, SHA1;

const
  CMagic = 'NXPM0001';

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
  LIndex: Integer;
begin
  CheckRange(AData, AOffset, ASize);
  Result := 0;
  for LIndex := 0 to ASize - 1 do
    Result := Result or (QWord(AData[AOffset + QWord(LIndex)]) shl (LIndex * 8));
end;

procedure PutNumber(var AData: TBytes; AOffset: Integer; AValue: Cardinal);
var
  LIndex: Integer;
begin
  for LIndex := 0 to 3 do
    AData[AOffset + LIndex] := Byte(AValue shr (LIndex * 8));
end;

function IsText(const AData: TBytes; AOffset: QWord; const AText: string): Boolean;
var
  LIndex: Integer;
begin
  CheckRange(AData, AOffset, Length(AText));
  for LIndex := 1 to Length(AText) do
    if AData[AOffset + QWord(LIndex - 1)] <> Ord(AText[LIndex]) then Exit(False);
  Result := True;
end;

procedure CheckHeader(const AData: TBytes);
begin
  CheckRange(AData, 0, NexusPackageEnvelopeSize);
  if not IsText(AData, 0, CMagic) then Invalid('unsupported storage format');
  if Number(AData, 8, 4) > 1 then Invalid('invalid storage mode');
  if (Number(AData, 12, 4) < 32) or
     (Number(AData, 12, 4) > High(LongInt)) or
     (Number(AData, 16, 4) < 8) or
     (Number(AData, 16, 4) > High(LongInt) - NexusPackageEnvelopeSize) then
    Invalid('invalid metadata size');
end;

function EncodePackageMetadata(const AData: TBytes): TBytes;
var
  LSize: Cardinal;
  LDigest: TSHA1Digest;
begin
  Result := nil;
  if (Length(AData) < 32) or (Length(AData) > High(LongInt) div 2) then
    Invalid('metadata size cannot be encoded');
  LSize := Length(AData) + Length(AData) div 1000 + 64;
  SetLength(Result, NexusPackageEnvelopeSize + LSize);
  Move(CMagic[1], Result[0], Length(CMagic));
  PutNumber(Result, 8, 1);
  PutNumber(Result, 12, Length(AData));
  if Compress2(@Result[NexusPackageEnvelopeSize], LSize, AData,
    Length(AData), Z_DEFAULT_COMPRESSION) <> Z_OK then
    Invalid('compression failed');
  PutNumber(Result, 16, LSize);
  LDigest := SHA1Buffer(AData[0], Length(AData));
  Move(LDigest[0], Result[20], SizeOf(LDigest));
  SetLength(Result, NexusPackageEnvelopeSize + LSize);
end;

function DecodePackageMetadata(const AEnvelope: TBytes): TBytes;
var
  LStream: z_stream;
  LDigest: TSHA1Digest;
  LCode: Integer;
begin
  Result := nil;
  CheckHeader(AEnvelope);
  if Number(AEnvelope, 8, 4) <> 1 then Invalid('metadata payload is absent');
  if Number(AEnvelope, 16, 4) <> QWord(Length(AEnvelope) - NexusPackageEnvelopeSize) then
    Invalid('compressed size does not match payload');
  FillChar(LStream, SizeOf(LStream), 0);
  LStream.next_in := @AEnvelope[NexusPackageEnvelopeSize];
  LStream.avail_in := Length(AEnvelope) - NexusPackageEnvelopeSize;
  SetLength(Result, Number(AEnvelope, 12, 4));
  LStream.next_out := @Result[0];
  LStream.avail_out := Length(Result);
  if InflateInit(LStream) <> Z_OK then Invalid('decompressor initialization failed');
  try
    LCode := Inflate(LStream, Z_FINISH);
    if (LCode <> Z_STREAM_END) or (LStream.avail_in <> 0) or
       (LStream.total_out <> Cardinal(Length(Result))) then
      Invalid('corrupt or truncated compressed payload');
  finally
    InflateEnd(LStream);
  end;
  LDigest := SHA1Buffer(Result[0], Length(Result));
  if not CompareMem(@LDigest[0], @AEnvelope[20], SizeOf(LDigest)) then
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
  LHandle: THandle;
  LSize: Int64;
begin
  Result := nil;
  LHandle := FileOpen(AFileName, fmOpenRead or fmShareDenyWrite);
  if LHandle = THandle(-1) then Invalid('cannot open ' + AFileName);
  try
    LSize := FileSeek(LHandle, Int64(0), 2);
    if (LSize < 0) or (LSize > High(LongInt)) then Invalid('unsupported file size');
    SetLength(Result, LSize);
    FileSeek(LHandle, Int64(0), 0);
    if (LSize > 0) and (FileRead(LHandle, Result[0], LSize) <> LSize) then
      Invalid('cannot read ' + AFileName);
  finally
    FileClose(LHandle);
  end;
end;

procedure WritePackageBytes(const AFileName: string; const AData: TBytes);
var
  LHandle: THandle;
begin
  LHandle := FileCreate(AFileName);
  if LHandle = THandle(-1) then Invalid('cannot create ' + AFileName);
  try
    if (Length(AData) > 0) and
       (FileWrite(LHandle, AData[0], Length(AData)) <> Length(AData)) then
      Invalid('cannot write ' + AFileName);
  finally
    FileClose(LHandle);
  end;
end;

function ImageMetadata(const AData: TBytes): TBytes;
var
  LTable, LCount, LStride, LNames, LNamesSize, LName, LSection: QWord;
  LOffset, LSize, LPE: QWord;
  LIndex: LongInt;
  LFound, LPEImage: Boolean;
begin
  Result := nil;
  LNames := 0;
  LNamesSize := 0;
  LPEImage := IsText(AData, 0, 'MZ');
  if LPEImage then
  begin
    LPE := Number(AData, 60, 4);
    if (Number(AData, LPE, 4) <> $4550) or
       (Number(AData, LPE + 4, 2) <> $8664) then Invalid('unsupported PE image');
    LCount := Number(AData, LPE + 6, 2);
    LStride := 40;
    LTable := LPE + 24 + Number(AData, LPE + 20, 2);
  end
  else
  begin
    if not IsText(AData, 0, #127'ELF') or (Number(AData, 4, 1) <> 2) or
       (Number(AData, 5, 1) <> 1) or (Number(AData, 18, 2) <> 62) then
      Invalid('unsupported ELF image');
    LTable := Number(AData, 40, 8);
    LStride := Number(AData, 58, 2);
    LCount := Number(AData, 60, 2);
    LIndex := Number(AData, 62, 2);
    if (LStride <> 64) or (LIndex >= LCount) then Invalid('invalid ELF section table');
    CheckRange(AData, LTable, LCount * LStride);
    LNames := Number(AData, LTable + LIndex * LStride + 24, 8);
    LNamesSize := Number(AData, LTable + LIndex * LStride + 32, 8);
    CheckRange(AData, LNames, LNamesSize);
  end;
  if LCount = 0 then Invalid('missing section table');
  CheckRange(AData, LTable, LCount * LStride);
  LFound := False;
  for LIndex := 0 to LongInt(LCount) - 1 do
  begin
    LSection := LTable + LIndex * LStride;
    if LPEImage then
    begin
      if not IsText(AData, LSection, NexusPackageMetadataSection + #0) then Continue;
      LOffset := Number(AData, LSection + 20, 4);
      LSize := Number(AData, LSection + 16, 4);
    end
    else
    begin
      LName := Number(AData, LSection, 4);
      if (LName >= LNamesSize) or
         (Length(NexusPackageMetadataSection) + 1 > LNamesSize - LName) then Continue;
      if not IsText(AData, LNames + LName, NexusPackageMetadataSection + #0) then Continue;
      if Number(AData, LSection + 4, 4) <> 1 then Invalid('invalid metadata section type');
      LOffset := Number(AData, LSection + 24, 8);
      LSize := Number(AData, LSection + 32, 8);
    end;
    if LFound then Invalid('duplicate metadata section');
    LFound := True;
    CheckRange(AData, LOffset, LSize);
    Result := System.Copy(AData, LOffset, LSize);
    CheckHeader(Result);
    LSize := NexusPackageEnvelopeSize;
    if Number(Result, 8, 4) = 1 then Inc(LSize, Number(Result, 16, 4));
    CheckRange(Result, 0, LSize);
    { PE section raw data is rounded to file alignment. }
    SetLength(Result, LSize);
  end;
  if not LFound then Invalid('image has no ' + NexusPackageMetadataSection + ' section');
end;

function ReadPackageMetadata(const AImageName: string): TBytes;
var
  LEnvelope, LSidecar: TBytes;
begin
  LEnvelope := ImageMetadata(ReadPackageBytes(AImageName));
  if Number(LEnvelope, 8, 4) = 0 then
  begin
    LSidecar := ReadPackageBytes(ChangeFileExt(AImageName, '.nxp'));
    CheckHeader(LSidecar);
    if not CompareMem(@LEnvelope[12], @LSidecar[12], NexusPackageEnvelopeSize - 12) then
      Invalid('sidecar does not match package image');
    LEnvelope := LSidecar;
  end;
  Result := DecodePackageMetadata(LEnvelope);
end;

end.
