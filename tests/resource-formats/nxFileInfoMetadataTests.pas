program NXFileInfoMetadataTests;

{$mode objfpc}{$H+}

uses
  obNXTestRegistry, obNXTestContext, utNXTestConsole,
  SysUtils, FileInfo, Resource, VersionTypes,
  ResReader, WinPEImageReader, ELFReader, MachOReader;

var TestContext: TNXTestContext;

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
procedure RunCase(AContext: TNXTestContext);
begin
  TestContext := AContext;
  if ParamCount <> 2 then
  begin
    WriteLn(StdErr, 'Usage: nxFileInfoMetadataTests <version-1.2.3.4> <version-5.6.7.8>');
    AContext.Fail('Expected two executable metadata fixtures');
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
end;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lRegistry.AddSuite('Resources.ImageMetadata').AddTest('RepeatedVersionLoading', @RunCase, 'resources');
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
