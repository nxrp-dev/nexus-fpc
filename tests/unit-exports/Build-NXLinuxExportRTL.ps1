# Copyright (c) 2026 Kevin Collins.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses",
# as defined by the Mozilla Public License, v. 2.0.
#
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$Compiler,
    [string]$Make = 'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\make.exe',
    [string]$OutputRoot = (Join-Path $env:TEMP ('nx-linux-export-rtl-' + [guid]::NewGuid().ToString('N').Substring(0,8)))
)
$ErrorActionPreference = 'Stop'
if (-not $SourceRoot) { $SourceRoot = Join-Path $PSScriptRoot '..\..' }
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
if (-not $Compiler) { $Compiler = Join-Path $SourceRoot 'compiler\ppcx64.exe' }
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$llvmBin = Split-Path (Get-Command clang.exe -ErrorAction Stop).Source
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $OutputRoot) { throw 'OutputRoot must be new' }
New-Item -ItemType Directory -Path $OutputRoot | Out-Null
$oldPath = $env:PATH
try {
    $env:PATH = $llvmBin+';'+$oldPath
    $makeArgs = @('-C', (Join-Path $SourceRoot 'rtl\linux'),
        'system.ppu', 'objpas.ppu', 'fpintres.ppu', 'si_prc.ppu', 'si_dll.ppu', 'abitag.o',
        ('FPC='+$Compiler.Replace('\','/')), 'OS_TARGET=linux', 'CPU_TARGET=x86_64',
        'OPT=-n -Aas-clang -XP -Cg',
        ('COMPILER_UNITTARGETDIR='+$OutputRoot.Replace('\','/')),
        'AS=clang --target=x86_64-unknown-linux-gnu -x assembler -c', 'ASTARGET=')
    $makeArgs | ConvertTo-Json | Set-Content "$OutputRoot\arguments.json"
    $ErrorActionPreference = 'Continue'
    & $Make @makeArgs *> "$OutputRoot\build.log"
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($code -ne 0) { throw "Linux regression RTL build failed ($code): $OutputRoot\build.log" }
    foreach ($artifact in @('system.ppu','objpas.ppu','fpintres.ppu','si_prc.ppu','si_dll.ppu','abitag.o')) {
        if (-not (Test-Path -LiteralPath (Join-Path $OutputRoot $artifact))) { throw "Missing $artifact" }
    }
    Write-Host "PASS Linux regression RTL: $OutputRoot"
} finally { $env:PATH = $oldPath }
