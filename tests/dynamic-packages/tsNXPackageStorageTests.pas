// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
unit tsNXPackageStorageTests;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterPackageStorageTests(ARegistry: TNXTestRegistry);
implementation
uses SysUtils, NXPackageFile, obNXTestContext, obNXTestSuite;

function Payload: TBytes;
var lIndex: Integer;
begin
  SetLength(Result, 1024);
  for lIndex := 0 to High(Result) do Result[lIndex] := lIndex mod 256;
end;

procedure Put(var AData: TBytes; AOffset: Integer; AValue: Cardinal);
var lByte: Integer;
begin
  for lByte := 0 to 3 do AData[AOffset + lByte] := Byte(AValue shr (lByte * 8));
end;

procedure TestStorage(AContext: TNXTestContext);
var lRaw, lEncoded, lDecoded, lReference: TBytes;
begin
  lRaw := Payload;
  lEncoded := EncodePackageMetadata(lRaw);
  AContext.AssertEquals(20, NexusPackageEnvelopeSize, 'Only the structural header');
  AContext.AssertTrue(CompareMem(@lEncoded[0], PChar('NXPM0002'), 8), 'Storage version');
  lDecoded := DecodePackageMetadata(lEncoded);
  AContext.AssertEquals(Length(lRaw), Length(lDecoded));
  AContext.AssertTrue(CompareMem(@lRaw[0], @lDecoded[0], Length(lRaw)), 'Exact raw bytes');
  lReference := PackageMetadataReference(lEncoded);
  AContext.AssertEquals(20, Length(lReference), 'Reference has no fingerprint');
  AContext.AssertEquals(0, lReference[8]);
end;

procedure TestMalformedStorage(AContext: TNXTestContext);
var
  lEncoded, lBad: TBytes;
  lIndex: Integer;
  lRejected: Boolean;
begin
  lEncoded := EncodePackageMetadata(Payload);
  for lIndex := 0 to 9 do
  begin
    lBad := Copy(lEncoded);
    case lIndex of
      0: SetLength(lBad, 19);
      1: lBad[0] := 0;
      2: Put(lBad, 8, 2);
      3: Put(lBad, 12, 31);
      4: Put(lBad, 12, 1023);
      5: Put(lBad, 16, Length(lBad));
      6: lBad[NexusPackageEnvelopeSize] := 0;
      7: SetLength(lBad, Length(lBad) - 1);
      8: lBad[High(lBad)] := lBad[High(lBad)] xor 1;
      9: begin
        SetLength(lBad, Length(lBad) + 1);
        Put(lBad, 16, Length(lBad) - NexusPackageEnvelopeSize);
      end;
    end;
    lRejected := False;
    try DecodePackageMetadata(lBad);
    except on E: Exception do lRejected := True; end;
    AContext.AssertTrue(lRejected, 'Malformed storage ' + IntToStr(lIndex));
  end;
end;

procedure TestOldStorage(AContext: TNXTestContext);
var lOld: TBytes; lRejected: Boolean;
begin
  lOld := EncodePackageMetadata(Payload);
  lOld[7] := Ord('1');
  lRejected := False;
  try DecodePackageMetadata(lOld);
  except on E: Exception do
    lRejected := Pos('rebuild', E.Message) > 0;
  end;
  AContext.AssertTrue(lRejected, 'Old storage requires rebuilding');
end;

procedure RegisterPackageStorageTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('PackageStorage');
  lSuite.AddTest('Storage', @TestStorage, 'package-storage');
  lSuite.AddTest('MalformedStorage', @TestMalformedStorage, 'package-storage');
  lSuite.AddTest('OldStorage', @TestOldStorage, 'package-storage');
end;
end.
