// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
unit utNXCollationData;
{$mode objfpc}{$H+}
interface
uses Classes;

procedure LoadCollationData(AStream: TMemoryStream;
  const AArchiveName, AEntryName: string);

implementation
uses SysUtils, Zipper;

type
  TCollationExtractor = class(TUnZipper)
  private
    FDestination: TMemoryStream;
    procedure OpenStream(ASender: TObject; var AStream: TStream;
      AItem: TFullZipFileEntry);
    procedure CloseStream(ASender: TObject; var AStream: TStream;
      AItem: TFullZipFileEntry);
  public
    constructor Create(ADestination: TMemoryStream);
  end;

constructor TCollationExtractor.Create(ADestination: TMemoryStream);
begin
  inherited Create;
  FDestination := ADestination;
  OnCreateStream := @OpenStream;
  OnDoneStream := @CloseStream;
end;

procedure TCollationExtractor.OpenStream(ASender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
begin
  AStream := FDestination;
end;

procedure TCollationExtractor.CloseStream(ASender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
begin
  // The test owns and frees the destination, including when extraction fails.
  AStream := nil;
end;

procedure LoadCollationData(AStream: TMemoryStream;
  const AArchiveName, AEntryName: string);
var
  lExtractor: TCollationExtractor;
begin
  AStream.Clear;
  lExtractor := TCollationExtractor.Create(AStream);
  try
    try
      lExtractor.UnZipFile(AArchiveName, AEntryName);
      // TUnZipper silently ignores a missing member; test inputs must be nonempty.
      if AStream.Size = 0 then
        raise EReadError.CreateFmt('Missing or empty collation fixture: %s', [AEntryName]);
      AStream.Position := 0;
    except
      AStream.Clear;
      raise;
    end;
  finally
    lExtractor.Free;
  end;
end;
end.
