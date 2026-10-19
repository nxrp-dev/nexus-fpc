{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
program little_endian_metadata;
{$mode objfpc}{$H+}
uses obNXTestRegistry, obNXTestContext, utNXTestConsole, SysUtils, PPU, PCP, NXArtifactID;
var TestContext: TNXTestContext;

const
  cFlags: array[0..3] of Cardinal = ($1000, 4, $1004, 0);
var
  lUnitHeader: TPPUHeader;
  lPackageHeader: TPCPHeader;
  lUnit: TPPUFile;
  lPackage: TPCPFile;
  lFile: File;
  lFlags: Cardinal;
  lName: string;
  lIndex: Integer;
  lExpected: Boolean;
procedure RunCase(AContext: TNXTestContext);
begin
  TestContext := AContext;
  for lFlags in cFlags do
  begin
    lExpected := lFlags = $1000;
    FillChar(lUnitHeader, SizeOf(lUnitHeader), 0);
    FillChar(lPackageHeader, SizeOf(lPackageHeader), 0);
    for lIndex := 1 to 3 do
    begin
      lUnitHeader.Common.ID[lIndex] := NexusPPUSignature[lIndex];
      lPackageHeader.Common.ID[lIndex] := NexusPCPSignature[lIndex];
    end;
    lUnitHeader.Common.Flags := lFlags;
    lPackageHeader.Common.Flags := lFlags;
    lName := IncludeTrailingPathDelimiter(ParamStr(1)) + 'byte-order-' + IntToHex(lFlags, 4);
    Assign(lFile, lName + '.nxu');
    Rewrite(lFile, 1);
    BlockWrite(lFile, lUnitHeader, SizeOf(lUnitHeader));
    Close(lFile);
    lUnit := TPPUFile.Create(lName + '.nxu');
    try
      if not lUnit.OpenFile or (lUnit.CheckPPUId <> lExpected) then
        raise Exception.Create('Unit header validation: ' + lName);
    finally
      lUnit.Free;
    end;
    Assign(lFile, lName + '.nxp');
    Rewrite(lFile, 1);
    BlockWrite(lFile, lPackageHeader, SizeOf(lPackageHeader));
    Close(lFile);
    lPackage := TPCPFile.Create(lName + '.nxp');
    try
      if not lPackage.OpenFile or (lPackage.CheckPCPID <> lExpected) then
        raise Exception.Create('Package header validation: ' + lName);
    finally
      lPackage.Free;
    end;
  end;
  WriteLn('PASS NXU/NXP: accept little-endian; reject retired, mixed and missing byte-order flags');
end;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lRegistry.AddSuite('Compiler.ArtifactHeaders').AddTest('ByteOrderValidation', @RunCase, 'compiler-units');
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
