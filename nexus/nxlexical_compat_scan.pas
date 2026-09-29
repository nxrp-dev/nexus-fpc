program nxlexical_compat_scan;

{$mode objfpc}{$H+}

uses
  Classes,
  SysUtils,
  nxPasTokenTypes,
  nxPasTokenizer;

var
  FilesScanned: QWord;
  FilesRejected: QWord;
  ConditionalStructureReviews: QWord;

function IsPascalSource(const AFileName: string): Boolean;
var
  Extension: string;
begin
  Extension := LowerCase(ExtractFileExt(AFileName));
  Result :=
    (Extension = '.pas') or
    (Extension = '.pp') or
    (Extension = '.inc');
end;

function LoadFileBytes(const AFileName: string): string;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, Stream.Size);
    if Stream.Size > 0 then
      Stream.ReadBuffer(Result[1], Stream.Size);
  finally
    Stream.Free;
  end;
end;

procedure ScanFile(const AFileName: string);
var
  Depth: Integer;
  I: Integer;
  Kind: TNXDirectiveKind;
  StructureFailed: Boolean;
  Tokens: TNXTokenBuffer;
  Tokenizer: TNXTokenizer;
begin
  Inc(FilesScanned);
  Tokenizer := TNXTokenizer.Create;
  try
    try
      Tokenizer.Start(AFileName, LoadFileBytes(AFileName));
      Tokenizer.Continue;
      Tokens := Tokenizer.Tokens;
      Depth := 0;
      StructureFailed := False;

      for I := 0 to High(Tokens) do
        if Tokens[I].Kind = tkDirective then
        begin
          Kind := TNXDirectiveKind(Tokens[I].Variant);
          if Kind in [dkIfDef, dkIfNDef, dkIf, dkIfOpt] then
            Inc(Depth)
          else if Kind in [dkElse, dkElseIf] then
          begin
            if Depth = 0 then
            begin
              Inc(ConditionalStructureReviews);
              WriteLn(
                'STRUCTURE|', AFileName,
                '|unmatched conditional branch at line ', Tokens[I].Line
              );
              StructureFailed := True;
              Break;
            end;
          end
          else if Kind in [dkEndIf, dkIfEnd] then
          begin
            if Depth = 0 then
            begin
              Inc(ConditionalStructureReviews);
              WriteLn(
                'STRUCTURE|', AFileName,
                '|unmatched conditional end at line ', Tokens[I].Line
              );
              StructureFailed := True;
              Break;
            end;
            Dec(Depth);
          end;
        end;

      if (Depth <> 0) and not StructureFailed then
      begin
        Inc(ConditionalStructureReviews);
        WriteLn(
          'STRUCTURE|', AFileName,
          '|conditional depth at physical EOF is ', Depth
        );
      end;
    except
      on E: Exception do
      begin
        Inc(FilesRejected);
        WriteLn(AFileName, '|', E.Message);
      end;
    end;
  finally
    Tokenizer.Free;
  end;
end;

procedure ScanDirectory(const ADirectory: string);
var
  Entry: TSearchRec;
  Path: string;
begin
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*', faAnyFile, Entry) <> 0 then
    Exit;

  try
    repeat
      if (Entry.Name = '.') or (Entry.Name = '..') then
        Continue;

      Path := IncludeTrailingPathDelimiter(ADirectory) + Entry.Name;
      if (Entry.Attr and faDirectory) <> 0 then
        ScanDirectory(Path)
      else if IsPascalSource(Entry.Name) then
        ScanFile(Path);
    until FindNext(Entry) <> 0;
  finally
    FindClose(Entry);
  end;
end;

var
  I: Integer;
begin
  if ParamCount = 0 then
    raise Exception.Create('Provide one or more source directories');

  for I := 1 to ParamCount do
    ScanDirectory(ExpandFileName(ParamStr(I)));

  WriteLn(
    'SUMMARY|scanned=', FilesScanned,
    '|rejected=', FilesRejected,
    '|structure_reviews=', ConditionalStructureReviews
  );
end.
