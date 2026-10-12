# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [string]$IdentityFile = 'build/forge-bootstrap/seed/build-identity.json'
)
$ErrorActionPreference = 'Stop'
$identity = Get-Content -LiteralPath $IdentityFile -Raw | ConvertFrom-Json
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$version = & $Compiler -iW
if ($LASTEXITCODE -ne 0) { throw 'Compiler failed to report its build identity.' }
if (-not ([string]$version).EndsWith('-' + $identity.Identity, [StringComparison]::Ordinal)) {
    throw "Compiler identity mismatch: $version; expected suffix $($identity.Identity)"
}
$date = & $Compiler -iD
if ($LASTEXITCODE -ne 0) { throw 'Compiler failed to report its build date.' }
if ($date -ne $identity.Date) {
    throw "Compiler date mismatch: $date; expected $($identity.Date)"
}
Write-Host "Verified compiler identity: $version [$date]"
