(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit ResourceInputs;

{$mode objfpc}{$H+}

interface

uses
  Classes, ResourceCatalog;

procedure LoadFormResource(ACatalog: TResourceCatalog; AStream: TStream;
  const AOrigin: string);
procedure LoadTypeLibraryResource(ACatalog: TResourceCatalog; AStream: TStream;
  const AOrigin: string);

implementation

uses
  SysUtils;

type
  TInputSignature = array[0..3] of AnsiChar;

function Signature(AStream: TStream): TInputSignature;
var
  LPosition: Int64;
begin
  FillChar(Result, SizeOf(Result), 0);
  LPosition := AStream.Position;
  try
    AStream.Read(Result, SizeOf(Result));
  finally
    AStream.Position := LPosition;
  end;
end;

function NewInputEntry(const AOrigin: string): TResourceEntry;
begin
  Result := TResourceEntry.Create;
  Result.Origin := AOrigin;
  Result.MemoryFlags := $1010; { RES MF_MOVEABLE or MF_DISCARDABLE }
end;

procedure LoadFormResource(ACatalog: TResourceCatalog; AStream: TStream;
  const AOrigin: string);
var
  LBinary: TMemoryStream;
  LReader: TBinaryObjectReader;
  LEntry: TResourceEntry;
  LFlags: TFilerFlags;
  LChildPosition: Integer;
  LClassName, LComponentName: string;
  LStart: Int64;
begin
  LBinary := nil;
  LEntry := nil;
  try
    try
      if Signature(AStream) <> 'TPF0' then
      begin
        LBinary := TMemoryStream.Create;
        ObjectTextToBinary(AStream, LBinary);
        LBinary.Position := 0;
        AStream := LBinary;
      end;
      LStart := AStream.Position;
      LReader := TBinaryObjectReader.Create(AStream, 4096);
      try
        LReader.BeginRootComponent;
        LChildPosition := 0;
        LReader.BeginComponent(LFlags, LChildPosition, LClassName, LComponentName);
      finally
        LReader.Free;
      end;
      if LClassName = '' then raise EReadError.Create('Missing root component class');
      AStream.Position := LStart;
      LEntry := NewInputEntry(AOrigin);
      LEntry.ResourceType := ResourceId(10); { RT_RCDATA }
      LEntry.Name := ResourceName(UTF8Decode(LClassName));
      LEntry.Data := ReadResourceData(AStream, AOrigin);
    except
      on E: Exception do
        raise EResourceCatalog.CreateFmt('%s: invalid form resource: %s',
          [AOrigin, E.Message]);
    end;
    ACatalog.AddOwned(LEntry);
    LEntry := nil;
  finally
    LEntry.Free;
    LBinary.Free;
  end;
end;

procedure LoadTypeLibraryResource(ACatalog: TResourceCatalog; AStream: TStream;
  const AOrigin: string);
var
  LSignature: TInputSignature;
  LEntry: TResourceEntry;
begin
  LSignature := Signature(AStream);
  if (LSignature <> 'MSFT') and (LSignature <> 'SLTG') then
    raise EResourceCatalog.CreateFmt('%s: invalid type-library signature', [AOrigin]);
  LEntry := NewInputEntry(AOrigin);
  try
    LEntry.ResourceType := ResourceName('TYPELIB');
    { The existing converter reads each direct TLB into a fresh collection,
      assigning ID 1. Keep that public ID and normal duplicate diagnostics. }
    LEntry.Name := ResourceId(1);
    LEntry.Data := ReadResourceData(AStream, AOrigin);
    ACatalog.AddOwned(LEntry);
    LEntry := nil;
  finally
    LEntry.Free;
  end;
end;

end.
