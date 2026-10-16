program NXFileInfoMetadataTests;

{$mode objfpc}{$H+}

uses
  SysUtils, FileInfo, Resource, VersionTypes,
  ResReader, WinPEImageReader, ELFReader, MachOReader;

procedure CheckVersion(AInfo: TVersionInfo; const AFileName: string;
  AMajor, AMinor, ARelease, ABuild: Word);
var
  LVersion: TFileProductVersion;
begin
  AInfo.Load(AFileName);
  LVersion := AInfo.FixedInfo.FileVersion;
  if (LVersion[0] <> AMajor) or (LVersion[1] <> AMinor) or
     (LVersion[2] <> ARelease) or (LVersion[3] <> ABuild) then
    raise Exception.CreateFmt('Unexpected file version in %s', [AFileName]);
end;

var
  LInfo: TVersionInfo;
begin
  if ParamCount <> 2 then
  begin
    WriteLn(StdErr, 'Usage: nxFileInfoMetadataTests <version-1.2.3.4> <version-5.6.7.8>');
    Halt(2);
  end;
  LInfo := TVersionInfo.Create;
  try
    CheckVersion(LInfo, ParamStr(1), 1, 2, 3, 4);
    CheckVersion(LInfo, ParamStr(2), 5, 6, 7, 8);
    CheckVersion(LInfo, ParamStr(1), 1, 2, 3, 4);
  finally
    LInfo.Free;
  end;
  WriteLn('PASS: executable metadata reader and repeated version loading');
end.
