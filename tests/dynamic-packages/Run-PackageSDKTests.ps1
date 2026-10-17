# Copyright (c) 2026 Kevin Collins. SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputRoot,
      [string]$BootstrapBin='C:/lazarus/fpc/3.2.2/bin/i386-win32',
      [string]$SourceRoot=(Join-Path $PSScriptRoot '../..'),
      [string]$ExampleRoot,[switch]$FullSuite)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/PackageTestCommon.ps1"
Initialize-PackageTests $OutputRoot
$SourceRoot=(Resolve-Path $SourceRoot).Path; $BootstrapBin=(Resolve-Path $BootstrapBin).Path
. "$SourceRoot/tests/dynamic-packages/NexusFPCPackageArtifacts.ps1"
if(-not $ExampleRoot){$ExampleRoot=Join-Path $SourceRoot "../nexus-lab/examples/packages/runtime-loading"}
$ExampleRoot=(Resolve-Path -LiteralPath $ExampleRoot).Path
$lSource="$script:TestOutput/source"
Push-Location $SourceRoot
try {$lPaths=@(git -c core.quotepath=false ls-files -c -o --exclude-standard -- compiler rtl tests/dynamic-packages | Sort-Object -Unique)} finally {Pop-Location}
foreach($lPath in $lPaths){
    if(-not(Test-Path -LiteralPath "$SourceRoot/$lPath" -PathType Leaf)){continue}
    New-Item -ItemType Directory -Force (Split-Path "$lSource/$lPath") | Out-Null
    Copy-Item -LiteralPath "$SourceRoot/$lPath" -Destination "$lSource/$lPath"
}
$lBefore=Get-TestHashes $lSource
Assert-PackageTest (-not(Test-Path "$lSource/compiler/msgtxt.inc") -and -not(Test-Path "$lSource/rtl/units")) 'Source snapshot contains build artifacts'
Add-TestResult source-only-input @{Files=$lPaths.Count}
foreach($lSmart in @($false,$true)){
    $lMode=if($lSmart){'smart'}else{'normal'}
    $lCase="$script:TestOutput/$lMode"; $lSdk="$lCase/sdk"
    $null=Invoke-TestScript "$lMode-build-and-run" "$lSource/tests/dynamic-packages/Build-NexusFPCPackageSDK.ps1" @{
        SourceRoot=$lSource; ExampleRoot=$ExampleRoot; OutputRoot=$lSdk; BootstrapBin=$BootstrapBin; RunExamples=$true; SmartLink=$lSmart
    }
    Assert-PackageTest ((Get-TestHashes $lSource) -ceq $lBefore) 'SDK build modified source inputs'
    Add-TestResult "$lMode-source-unchanged" @{}
    $lStatic="$lCase/static"
    Write-TestFile "$lStatic/static_host.pas" @'
program static_host;
{$mode objfpc}{$H+}
{$ifndef FPC_HAS_DYNAMIC_PACKAGES}{$fatal Missing package support}{$endif}
uses SysUtils, Classes;
var Values: TStringList;
begin
  Values:=TStringList.Create;
  try Values.Add(IntToStr(37)); if Values[0]<>'37' then Halt(1);
  finally Values.Free; end;
  WriteLn('PASS static host');
end.
'@
    $null=Invoke-TestProcess "$lMode-static-build" "$lSdk/bin/ppcx64.exe" ((Get-TestCompilerOptions $lSdk $lStatic)+@('-O2',"$lStatic/static_host.pas"))
    $null=Invoke-TestProcess "$lMode-static-runtime" "$lStatic/static_host.exe" @() 0 'PASS static host'
    $lImports=Invoke-TestProcess "$lMode-static-imports" llvm-readobj.exe @('--coff-imports',"$lStatic/static_host.exe")
    Assert-PackageTest (-not $lImports.ToLowerInvariant().Contains('nxrtl.dll')) 'Static host imports shared RTL'
    $lRelocated="$lCase/relocated-sdk"; $lProviders="$lCase/package-distribution"; $lHostSource="$lCase/host-source"
    New-Item -ItemType Directory -Force $lRelocated,$lProviders | Out-Null
    foreach($lDirectory in @('bin','packages','units')){Copy-Item "$lSdk/$lDirectory" $lRelocated -Recurse}
    Copy-Item "$lSdk/sdk.json" $lRelocated
    Get-ChildItem (Get-NexusPackageBundle "$lSdk/examples/packages") -File | Where-Object Extension -In '.nxp','.dll' | Copy-Item -Destination $lProviders
    Assert-PackageTest (@(Get-ChildItem $lProviders).Count -eq 8) 'Expected four binary package pairs'
    Copy-Item "$ExampleRoot/host" $lHostSource -Recurse
    Assert-PackageTest (@(Get-ChildItem $lHostSource | Where-Object Extension -NE '.pas').Count -eq 0) 'Host inputs must be source only'
    $lBinaryBefore=Get-TestHashes $lRelocated
    Move-TestArtifact $lSource "$script:TestOutput/source-unavailable"
    Move-TestArtifact $lSdk "$lCase/sdk-unavailable"
    try {
        foreach($lKind in @('console','gui')){
            $lName="demo_$lKind"; $lApp="$lCase/$lName"
            $null=Invoke-TestScript "$lMode-relocated-build-$lKind" "$lRelocated/bin/Invoke-NexusFPCPackageCompile.ps1" @{
                SdkRoot=$lRelocated; Source="$lHostSource/$lName.pas"; OutputDirectory=$lApp; Kind=$lKind
                PackagePath=$lProviders; RequiredPackages=@('demotypes','demoleft','demoright'); SmartLink=$lSmart
            }
            $lBundle=Get-NexusPackageBundle $lApp; $lResult="$lBundle/result.log"
            $null=Invoke-TestProcess "$lMode-relocated-run-$lKind" "$lBundle/$lName.exe" @($lResult)
            $lExpected=@('init=BLRH',"PASS $lKind",'final=h','final=r','final=l','final=b') -join "`n"
            Assert-PackageTest ((Get-Content $lResult -Raw).Replace("`r",'').Trim() -ceq $lExpected) 'Relocated lifecycle mismatch'
            $b=[IO.File]::ReadAllBytes("$lBundle/$lName.exe"); $p=[BitConverter]::ToUInt32($b,0x3c)
            Assert-PackageTest ([BitConverter]::ToUInt32($b,$p) -eq 0x4550 -and [BitConverter]::ToUInt16($b,$p+4) -eq 0x8664) 'Wrong PE target'
            Assert-PackageTest ([BitConverter]::ToUInt16($b,$p+24+68) -eq $(if($lKind -eq 'console'){3}else{2})) 'Wrong subsystem'
            Assert-PackageTest (((Get-ChildItem "$lBundle/*.dll" | Sort-Object Name).Name -join ',') -ceq 'demoleft.dll,demoright.dll,demotypes.dll,nxrtl.dll') 'Unexpected runtime dependencies'
            Add-TestResult "$lMode-relocated-lifecycle-and-subsystem-$lKind" @{}
        }
        Assert-PackageTest ((Get-TestHashes $lRelocated) -ceq $lBinaryBefore) 'Relocated SDK modified'
        Add-TestResult "$lMode-sdk-artifacts-unchanged" @{}
    } finally {
        Move-TestArtifact "$script:TestOutput/source-unavailable" $lSource
        Move-TestArtifact "$lCase/sdk-unavailable" $lSdk
    }
    if($FullSuite){
        # Metadata, link and low-level runtime exercise both link modes themselves.
        if(-not $lSmart){
            foreach($lSuite in @('Metadata','Link','Runtime')){
                $null=Invoke-TestScript "$lMode-$lSuite" "$PSScriptRoot/Run-Package${lSuite}Tests.ps1" @{SdkRoot=$lSdk; OutputRoot="$lCase/$lSuite"}
            }
        }
        $null=Invoke-TestScript "$lMode-Loader" "$PSScriptRoot/Run-PackageLoaderTests.ps1" @{SdkRoot=$lSdk; OutputRoot="$lCase/Loader"; SmartLink=$lSmart}
        $null=Invoke-TestScript "$lMode-Threadvar" "$PSScriptRoot/Run-ThreadvarPackageTests.ps1" @{SdkRoot=$lSdk; OutputRoot="$lCase/Threadvar"; SmartLink=$lSmart}
        $null=Invoke-TestScript "$lMode-real" "$PSScriptRoot/../compiler-real/Run-PackageRealTests.ps1" @{SdkRoot=$lSdk; OutputRoot="$lCase/real"; SmartLink=$lSmart}
    }
}
Write-Host "PASS package SDK workflow ($($script:TestSteps.Count) steps)"
