program RTLModeContract;

{$mode objfpc}

uses
  SysUtils;

{$IFDEF FPC_UNICODESTRINGS}
type
  TGetCurrentDirResult = function: UnicodeString;

procedure RequireRTLString(var Value: UnicodeString);
begin
end;

procedure RequireSearchRec(var Value: TUnicodeSearchRec);
begin
end;

procedure RequireSymLinkRec(var Value: TUnicodeSymLinkRec);
begin
end;
{$ELSE}
type
  TGetCurrentDirResult = function: AnsiString;

procedure RequireRTLString(var Value: AnsiString);
begin
end;

procedure RequireSearchRec(var Value: TRawByteSearchRec);
begin
end;

procedure RequireSymLinkRec(var Value: TRawByteSymLinkRec);
begin
end;
{$ENDIF}

var
  Text: RTLString;
  Search: TSearchRec;
  Link: TSymLinkRec;
  CurrentDir: TGetCurrentDirResult;

begin
  RequireRTLString(Text);
  RequireSearchRec(Search);
  RequireSymLinkRec(Link);
  CurrentDir := @GetCurrentDir;
  if CurrentDir() = '' then
    Halt(1);
end.
