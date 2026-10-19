# Copyright (c) 2026 Kevin Collins. SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SdkRoot,
    [Parameter(Mandatory)][string]$OutputRoot,
    [switch]$SmartLink
)
$ErrorActionPreference = 'Stop'
$lSource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$lNxtest = Join-Path $lSource '../nexus/packages/nexus-packages/nxtest/src'
if (-not (Test-Path -LiteralPath $lNxtest)) {
    $lNxtest = Join-Path $lSource '../../nexus/packages/nexus-packages/nxtest/src'
}
$lNxtest = (Resolve-Path -LiteralPath $lNxtest).Path
$SdkRoot = (Resolve-Path -LiteralPath $SdkRoot).Path
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
. "$lSource/tests/dynamic-packages/NexusFPCPackageArtifacts.ps1"
$lInputs = Join-Path $OutputRoot 'inputs'
New-Item -ItemType Directory -Force -Path "$lInputs/provider","$lInputs/consumer" | Out-Null
Copy-Item -LiteralPath "$PSScriptRoot/uextendedabi.pas" -Destination "$lInputs/provider"
Copy-Item -LiteralPath "$PSScriptRoot/textendedabi.pas" -Destination "$lInputs/consumer"
'package nativeabi; requires nxrtl; contains uextendedabi; end.' |
    Set-Content -LiteralPath "$lInputs/provider/nativeabi.nxpk" -Encoding ASCII
$lBuild = "$lSource/tests/dynamic-packages/Invoke-NexusFPCPackageCompile.ps1"
& $lBuild -SdkRoot $SdkRoot -Source "$lInputs/provider/nativeabi.nxpk" `
    -OutputDirectory "$OutputRoot/provider" -Kind Package -SmartLink:$SmartLink
& $lBuild -SdkRoot $SdkRoot -Source "$lInputs/consumer/textendedabi.pas" `
    -OutputDirectory "$OutputRoot/host" -Kind Console -RequiredPackages nativeabi `
    -PackagePath "$OutputRoot/provider" -UnitPath $lNxtest -SmartLink:$SmartLink
$lBundle = Get-NexusPackageBundle "$OutputRoot/host"
& "$lBundle/textendedabi.exe" *> "$OutputRoot/extended-run.log"
if ($LASTEXITCODE -ne 0) { throw 'Extended runtime package ABI test failed.' }
& llvm-readobj.exe --coff-imports "$lBundle/textendedabi.exe" *> "$OutputRoot/extended-imports.log"
if ($LASTEXITCODE -ne 0 -or
    (Get-Content -LiteralPath "$OutputRoot/extended-imports.log" -Raw) -notmatch 'nativeabi.dll') {
    throw 'Host must import the provider DLL; compiling the unit into the host is not this test.'
}
foreach ($lFixture in @('tests/compiler-real/tmathabi.pas','tests/tbs/tw1737.pas',
    'tests/rtl/fixtures/system/ttrig_tolerance.pas','tests/test/twrstr8.pas')) {
    $lName = [IO.Path]::GetFileNameWithoutExtension($lFixture)
    $lOutput = Join-Path $OutputRoot $lName
    & $lBuild -SdkRoot $SdkRoot -Source "$lSource/$lFixture" -OutputDirectory $lOutput -Kind Console -UnitPath $lNxtest -SmartLink:$SmartLink
    $lBundle = Get-NexusPackageBundle $lOutput
    & "$lBundle/$lName.exe" *> "$OutputRoot/$lName-run.log"
    if ($LASTEXITCODE -ne 0) { throw "$lName shared-RTL test failed." }
    Write-Output "PASS $lName"
}
Write-Output 'PASS Extended package ABI and shared-RTL math'
