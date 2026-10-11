# Copyright (c) 2026 Kevin Collins. SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$RTL,
    [ValidateSet('win32','win64')][string]$Target = 'win64',
    [Parameter(Mandatory)][string]$OutputRoot,
    [string]$ReferenceVectors
)
$ErrorActionPreference = 'Stop'
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$RTL = (Resolve-Path -LiteralPath $RTL).Path
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
$lSource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
[void](New-Item -ItemType Directory -Force -Path $OutputRoot)
$lResults = [Collections.Generic.List[object]]::new()

function Invoke-Check([string]$AName, [string]$AProgram, [string[]]$AArguments, [switch]$ExpectRangeError) {
    $lLog = Join-Path $OutputRoot ($AName + '.log')
    $lTimer = [Diagnostics.Stopwatch]::StartNew()
    $ErrorActionPreference = 'Continue'
    & $AProgram @AArguments *> $lLog
    $lCode = $LASTEXITCODE
    $lTimer.Stop()
    $ErrorActionPreference = 'Stop'
    $lResults.Add([pscustomobject]@{ Name=$AName; ExitCode=$lCode;
        ExpectedRangeError=[bool]$ExpectRangeError;
        Seconds=$lTimer.Elapsed.TotalSeconds; Command=@($AProgram)+$AArguments; Log=$lLog })
    $lResults.ToArray() | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$OutputRoot/results.json" -Encoding UTF8
    if ($ExpectRangeError) {
        $lText = Get-Content -LiteralPath $lLog -Raw
        if ($lCode -eq 0 -or $lText -notmatch 'Error:.*range check' -or $lText -match 'Internal error|Access violation') {
            Get-Content -LiteralPath $lLog -Tail 15
            throw "$AName did not produce the expected range diagnostic."
        }
    } elseif ($lCode -ne 0) { Get-Content -LiteralPath $lLog -Tail 15; throw "$AName failed ($lCode)." }
    Write-Output "$AName passed"
}

foreach ($lVariant in @('normal','O2')) {
    $lDirectory = Join-Path $OutputRoot $lVariant
    [void](New-Item -ItemType Directory -Force -Path $lDirectory)
    $lOptions = @('-n', "-T$Target", '-Aas-clang', '-XLL', "-Fu$RTL", "-FU$lDirectory", "-FE$lDirectory")
    if ($lVariant -eq 'O2') { $lOptions += '-O2' }
    Invoke-Check "$lVariant-core-build" $Compiler ($lOptions + @("-Fu$lSource/compiler", "$PSScriptRoot/tcompilerreal.pp"))
    Invoke-Check "$lVariant-core-run" "$lDirectory/tcompilerreal.exe" @()
    Invoke-Check "$lVariant-soft-integer-build" $Compiler ($lOptions + @("$PSScriptRoot/tsoftinteger.pp"))
    Invoke-Check "$lVariant-soft-integer-run" "$lDirectory/tsoftinteger.exe" @()
    Invoke-Check "$lVariant-abi-build" $Compiler ($lOptions + @("$PSScriptRoot/textendedabi.pp"))
    Invoke-Check "$lVariant-abi-run" "$lDirectory/textendedabi.exe" @()
    Invoke-Check "$lVariant-math-abi-build" $Compiler ($lOptions + @("$PSScriptRoot/tmathabi.pp"))
    Invoke-Check "$lVariant-math-abi-run" "$lDirectory/tmathabi.exe" @()
    $lCPU = if ($Target -eq 'win64') { 'x86_64' } else { 'i386' }
    Invoke-Check "$lVariant-rtti-build" $Compiler ($lOptions + @(
        "-Fu$lSource/packages/rtl-objpas/src/inc", "-Fu$lSource/packages/rtl-objpas/src/$lCPU",
        "-Fi$lSource/packages/rtl-objpas/src/$lCPU",
        "-Fi$lSource/packages/rtl-objpas/src/win", "$PSScriptRoot/textendedrtti.pp"))
    Invoke-Check "$lVariant-rtti-run" "$lDirectory/textendedrtti.exe" @()
    if ($Target -eq 'win64') {
        Invoke-Check "$lVariant-c-build" 'clang.exe' @('-target','x86_64-pc-windows-msvc','-O2','-c',
            "$PSScriptRoot/nativebridge.c",'-o',"$lDirectory/nativebridge.obj")
        Invoke-Check "$lVariant-c-link" 'lld-link.exe' @('/dll','/noentry','/nodefaultlib','/machine:x64',
            "/out:$lDirectory/nativebridge.dll","$lDirectory/nativebridge.obj")
        Invoke-Check "$lVariant-c-bridge-build" $Compiler ($lOptions + @("$PSScriptRoot/tcbridge.pp"))
        Invoke-Check "$lVariant-c-bridge-run" "$lDirectory/tcbridge.exe" @()
    }
    if ($ReferenceVectors) {
        Invoke-Check "$lVariant-reference-build" $Compiler ($lOptions + @("-Fu$lSource/compiler", "$PSScriptRoot/treference.pp"))
        Invoke-Check "$lVariant-reference-run" "$lDirectory/treference.exe" @((Resolve-Path -LiteralPath $ReferenceVectors).Path)
    }
    Copy-Item -LiteralPath "$PSScriptRoot/urealconstants.pp" -Destination $lDirectory
    Copy-Item -LiteralPath "$PSScriptRoot/tcachedreal.pp" -Destination $lDirectory
    Invoke-Check "$lVariant-fresh-build" $Compiler ($lOptions + @("-Fu$lDirectory", "$lDirectory/tcachedreal.pp"))
    Invoke-Check "$lVariant-fresh-run" "$lDirectory/tcachedreal.exe" @()
    $lHash = (Get-FileHash -LiteralPath "$lDirectory/urealconstants.ppu").Hash
    Remove-Item -LiteralPath "$lDirectory/urealconstants.pp"
    Invoke-Check "$lVariant-cached-build" $Compiler ($lOptions + @("-Fu$lDirectory", "$lDirectory/tcachedreal.pp"))
    Invoke-Check "$lVariant-cached-run" "$lDirectory/tcachedreal.exe" @()
    if ((Get-FileHash -LiteralPath "$lDirectory/urealconstants.ppu").Hash -ne $lHash) {
        throw 'The cached unit changed during the reuse test.'
    }
    $lIndex = 0
    foreach ($lLiteral in @('922337203685477.5808','-922337203685477.5809','1.0e30')) {
        $lIndex++
        $lInput = Join-Path $lDirectory ("range$lIndex.pp")
        "program range$lIndex; const cValue: Currency = $lLiteral; begin end." |
            Set-Content -LiteralPath $lInput -Encoding ASCII
        Invoke-Check "$lVariant-range-$lIndex" $Compiler ($lOptions + @($lInput)) -ExpectRangeError
    }
}
