unit nxPasFileSources;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  nxPasSources;

type
  TNXFileSourceProvider = class(TNXSourceProvider)
  private
    FIncludePaths: array of string;
    function TryLoad(
      const AFileName: string;
      out AResolvedName: string;
      out AText: string
    ): Boolean;
  public
    procedure AddIncludePath(const APath: string);

    function LoadInclude(
      const ACurrentSource: string;
      const AIncludeName: string;
      out AResolvedName: string;
      out AText: string
    ): Boolean; override;
  end;

implementation

procedure TNXFileSourceProvider.AddIncludePath(const APath: string);
var
  I: Integer;
begin
  I := Length(FIncludePaths);
  SetLength(FIncludePaths, I + 1);
  FIncludePaths[I] := ExpandFileName(APath);
end;

function TNXFileSourceProvider.TryLoad(
  const AFileName: string;
  out AResolvedName: string;
  out AText: string
): Boolean;
var
  Stream: TFileStream;
  Bytes: RawByteString;
begin
  Result := False;

  if not FileExists(AFileName) then
    Exit;

  AResolvedName := ExpandFileName(AFileName);

  Stream := TFileStream.Create(
    AResolvedName,
    fmOpenRead or fmShareDenyNone
  );
  try
    SetLength(Bytes, Stream.Size);

    if Length(Bytes) > 0 then
      Stream.ReadBuffer(Bytes[1], Length(Bytes));
  finally
    Stream.Free;
  end;

  AText := UTF8Decode(Bytes);
  Result := True;
end;

function TNXFileSourceProvider.LoadInclude(
  const ACurrentSource: string;
  const AIncludeName: string;
  out AResolvedName: string;
  out AText: string
): Boolean;
var
  Candidate: string;
  I: Integer;
begin
  if ExtractFilePath(ACurrentSource) <> '' then
  begin
    Candidate := ExpandFileName(
      IncludeTrailingPathDelimiter(
        ExtractFilePath(ACurrentSource)
      ) + AIncludeName
    );

    if TryLoad(Candidate, AResolvedName, AText) then
      Exit(True);
  end;

  for I := 0 to High(FIncludePaths) do
  begin
    Candidate := IncludeTrailingPathDelimiter(
      FIncludePaths[I]
    ) + AIncludeName;

    if TryLoad(Candidate, AResolvedName, AText) then
      Exit(True);
  end;

  Result := TryLoad(
    AIncludeName,
    AResolvedName,
    AText
  );
end;

end.
