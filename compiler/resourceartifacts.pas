(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit ResourceArtifacts;

{$mode objfpc}{$H+}

interface

uses
  Classes, ResourceCatalog, ResourceTools;

type
  TResourceInputKind = (rikRes, rikRC, rikForm, rikTypeLibrary);

  { Preparing an artifact never changes the published file. The owner prepares
    every module input before publishing any of them. An abandoned stage removes
    its temporary file. Scratch prefixes must be exclusive to the caller. }
  TResourceArtifactStage = class
  private
    FTemporaryFile: string;
    FPublishedFile: string;
    FBackupFile: string;
    FProvisional, FReplaced, FPreviousExists: Boolean;
  public
    constructor Create(ACatalog: TResourceCatalog;
      const APublishedFile, AScratchPrefix: string; AProvisional: Boolean = False);
    destructor Destroy; override;
    function Publish: Boolean; { True only when the published bytes changed. }
    procedure Commit;
    procedure Rollback;
    property PublishedFile: string read FPublishedFile;
  end;

function ResourceArtifactName(const AUnitFile: string; AInputIndex: Cardinal): string;
function NormalizeResourceInput(ACatalog: TResourceCatalog;
  ACompiler: TLLVMResourceCompiler; const ASource, AScratchPrefix: string): TResourceInputKind;

implementation

uses
  SysUtils, ResourceInputs
  {$ifdef windows}, Windows{$endif};

function ResourceArtifactName(const AUnitFile: string; AInputIndex: Cardinal): string;
var
  LOwner: string;
begin
  LOwner := ChangeFileExt(ExtractFileName(AUnitFile), '');
  if (LOwner = '') or (LOwner = '.') or (LOwner = '..') then
    raise EResourceCatalog.Create('Missing module identity for resource artifact');
  Result := LOwner + '.nxr' + IntToStr(AInputIndex) + '.res';
end;

function NormalizeResourceInput(ACatalog: TResourceCatalog;
  ACompiler: TLLVMResourceCompiler; const ASource, AScratchPrefix: string): TResourceInputKind;
var
  LStream: TFileStream;
  LSignature: array[0..3] of AnsiChar;
  LExtension: string;
begin
  if (ACatalog = nil) or (ACatalog.Count <> 0) then
    raise EResourceCatalog.Create('Resource input normalization requires an empty catalog');
  LStream := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
  try
    { RES signature takes precedence over the extension, including .dcr files. }
    if HasResSignature(LStream) then
    begin
      ACatalog.LoadRes(LStream, ASource);
      Exit(rikRes);
    end;
    FillChar(LSignature, SizeOf(LSignature), 0);
    LStream.Read(LSignature, SizeOf(LSignature));
    LStream.Position := 0;
    LExtension := LowerCase(ExtractFileExt(ASource));
    if LSignature = 'TPF0' then Result := rikForm
    else if (LSignature = 'MSFT') or (LSignature = 'SLTG') then Result := rikTypeLibrary
    else if (LExtension = '.dfm') or (LExtension = '.lfm') or
      (LExtension = '.xfm') or (LExtension = '.fmx') then Result := rikForm
    else if LExtension = '.tlb' then Result := rikTypeLibrary
    else if LExtension = '.rc' then Result := rikRC
    else
      raise EResourceCatalog.CreateFmt('%s: unsupported resource input format', [ASource]);
    case Result of
      rikForm: LoadFormResource(ACatalog, LStream, ASource);
      rikTypeLibrary: LoadTypeLibraryResource(ACatalog, LStream, ASource);
    end;
  finally
    LStream.Free;
  end;
  if Result = rikRC then
  begin
    if ACompiler = nil then
      raise EResourceTool.CreateFmt('%s: LLVM RC configuration is required', [ASource]);
    ACompiler.CompileRC(ACatalog, ASource, AScratchPrefix);
  end;
end;

function SameFileContents(const AFirst, ASecond: string): Boolean;
var
  LFirst, LSecond: TFileStream;
  LFirstBuffer, LSecondBuffer: array[0..65535] of Byte;
  LCount: LongInt;
begin
  Result := False;
  if not FileExists(ASecond) then Exit;
  LFirst := TFileStream.Create(AFirst, fmOpenRead or fmShareDenyWrite);
  try
    LSecond := TFileStream.Create(ASecond, fmOpenRead or fmShareDenyWrite);
    try
      if LFirst.Size <> LSecond.Size then Exit;
      repeat
        LCount := LFirst.Read(LFirstBuffer, SizeOf(LFirstBuffer));
        if LCount = 0 then Break;
        LSecond.ReadBuffer(LSecondBuffer, LCount);
        if not CompareMem(@LFirstBuffer[0], @LSecondBuffer[0], LCount) then Exit;
      until False;
      Result := True;
    finally
      LSecond.Free;
    end;
  finally
    LFirst.Free;
  end;
end;

constructor TResourceArtifactStage.Create(ACatalog: TResourceCatalog;
  const APublishedFile, AScratchPrefix: string; AProvisional: Boolean);
begin
  inherited Create;
  if (ACatalog = nil) or (APublishedFile = '') or (AScratchPrefix = '') then
    raise EResourceCatalog.Create('Resource stage requires a catalog, output and exclusive scratch prefix');
  FPublishedFile := ExpandFileName(APublishedFile);
  FTemporaryFile := ExpandFileName(AScratchPrefix) + '.canonical.res';
  FProvisional := AProvisional;
  FBackupFile := FTemporaryFile + '.previous';
  if (AnsiCompareFileName(FPublishedFile, FTemporaryFile) = 0) or
    (AnsiCompareFileName(ExtractFilePath(FPublishedFile),
      ExtractFilePath(FTemporaryFile)) <> 0) then
  begin
    FTemporaryFile := '';
    raise EResourceCatalog.Create('Resource stage must be a distinct file beside its published artifact');
  end;
  ACatalog.SaveRes(FTemporaryFile);
end;

destructor TResourceArtifactStage.Destroy;
begin
  Rollback;
  if FTemporaryFile <> '' then SysUtils.DeleteFile(FTemporaryFile);
  if FBackupFile <> '' then SysUtils.DeleteFile(FBackupFile);
  inherited Destroy;
end;

procedure TResourceArtifactStage.Commit;
begin
  FProvisional := False;
  if FBackupFile <> '' then SysUtils.DeleteFile(FBackupFile);
  FBackupFile := '';
end;

procedure TResourceArtifactStage.Rollback;
begin
  if not (FProvisional and FReplaced) then Exit;
  if FPreviousExists then
  begin
{$ifdef windows}
    if not MoveFileExW(PWideChar(UnicodeString(FBackupFile)),
      PWideChar(UnicodeString(FPublishedFile)), MOVEFILE_REPLACE_EXISTING) then
{$else}
    if not RenameFile(FBackupFile, FPublishedFile) then
{$endif}
      raise EResourceCatalog.CreateFmt('Cannot restore resource artifact %s', [FPublishedFile]);
  end
  else if FileExists(FPublishedFile) and not SysUtils.DeleteFile(FPublishedFile) then
    raise EResourceCatalog.CreateFmt('Cannot remove abandoned resource artifact %s', [FPublishedFile]);
  FReplaced := False;
end;

function TResourceArtifactStage.Publish: Boolean;
var
  LReplaced: Boolean;
  LSource, LBackup: TFileStream;
  LBuffer: array[0..65535] of Byte;
  LCount: LongInt;
begin
  if FTemporaryFile = '' then
    raise EResourceCatalog.Create('Resource artifact stage was already published');
  Result := not SameFileContents(FTemporaryFile, FPublishedFile);
  if Result then
  begin
    if FProvisional then
    begin
      FPreviousExists := FileExists(FPublishedFile);
      if FPreviousExists then
      begin
        LSource := TFileStream.Create(FPublishedFile, fmOpenRead or fmShareDenyWrite);
        try
          LBackup := TFileStream.Create(FBackupFile, fmCreate);
          try
            repeat
              LCount := LSource.Read(LBuffer, SizeOf(LBuffer));
              if LCount <> 0 then LBackup.WriteBuffer(LBuffer, LCount);
            until LCount = 0;
          finally
            LBackup.Free;
          end;
          if FileSetDate(FBackupFile, FileAge(FPublishedFile)) <> 0 then
            raise EResourceCatalog.CreateFmt('Cannot preserve resource artifact timestamp %s', [FPublishedFile]);
        finally
          LSource.Free;
        end;
      end;
    end;
    { Both paths are on the same filesystem. Never delete/move the published
      artifact first: a failed replacement must leave it available unchanged. }
    {$ifdef windows}
    LReplaced := MoveFileExW(PWideChar(UnicodeString(FTemporaryFile)),
      PWideChar(UnicodeString(FPublishedFile)), MOVEFILE_REPLACE_EXISTING);
    {$else}
    LReplaced := RenameFile(FTemporaryFile, FPublishedFile);
    {$endif}
    if not LReplaced then
      raise EResourceCatalog.CreateFmt('%s: cannot publish normalized resource: %s',
        [FPublishedFile, SysErrorMessage(GetLastOSError)]);
    FReplaced := True;
  end
  else if not SysUtils.DeleteFile(FTemporaryFile) then
    raise EResourceCatalog.CreateFmt('%s: cannot remove unchanged resource stage',
      [FTemporaryFile]);
  FTemporaryFile := '';
end;

end.
