# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
<#
.SYNOPSIS
Write package identities/options and the completed Forge SDK manifest.
.DESCRIPTION
Forge owns staging and compilation. This helper only writes build metadata.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('Options','Manifest')][string]$Phase,
    [string]$SourceRoot
)
$ErrorActionPreference = 'Stop'
if (-not $SourceRoot) { $SourceRoot = Join-Path $PSScriptRoot '..' }
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$bootstrap = Join-Path $SourceRoot 'build/forge-bootstrap'
$sdk = Join-Path $bootstrap 'package-sdk'
$work = Join-Path $sdk 'work'
$compiler = Join-Path $sdk 'bin/ppcx64.exe'
$encoding = [Text.UTF8Encoding]::new($false)

if ($Phase -eq 'Options') {
    # Bind the actual compiled RTL as well as the staged sources. This includes
    # the source of FPCPackage and SysInitPkg compiled by the SDK recipe itself.
    $parts = [Collections.Generic.List[string]]::new()
    $parts.Add((Get-FileHash -LiteralPath $compiler).Hash)
    $parts.Add('x86_64-win64;-O2;-Ur;-Xs')
    foreach ($directory in @((Join-Path $work 'rtl-units'), (Join-Path $bootstrap 'seed/rtl'))) {
        foreach ($file in Get-ChildItem -LiteralPath $directory -Recurse -File | Sort-Object FullName) {
            $parts.Add($file.FullName.Substring($directory.Length).Replace('\','/') + ':' +
                (Get-FileHash -LiteralPath $file.FullName).Hash)
        }
    }
    $parts.Add((Get-FileHash -LiteralPath (Join-Path $bootstrap 'seed/build-options.cfg')).Hash)
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $identity = [BitConverter]::ToString($hash.ComputeHash($encoding.GetBytes(($parts -join "`n")))).Replace('-','') }
    finally { $hash.Dispose() }
    $build = [guid]::NewGuid().ToString('N').ToUpperInvariant()
    [IO.File]::WriteAllText((Join-Path $work 'identity.json'),
        ([ordered]@{SDK=$identity; Build=$build} | ConvertTo-Json) + "`n", $encoding)
    [IO.File]::WriteAllText((Join-Path $work 'foundation.cfg'), "-Fj$identity`n-Fk$build`n", $encoding)
    # FPC reads one option per line, including spaces in paths. Package search
    # paths must precede -FP, which loads the package while reading the file.
    [IO.File]::WriteAllText((Join-Path $work 'startup.cfg'),
        "-Fj$identity`n-Fp$($sdk.Replace('\','/'))/packages`n-FPnxrtl`n", $encoding)
    Write-Host "Package SDK identity: $identity"
    exit 0
}

. (Join-Path $PSScriptRoot 'NexusFPCPackageArtifacts.ps1')
$identity = Get-Content -LiteralPath (Join-Path $work 'identity.json') -Raw | ConvertFrom-Json
$metadata = Read-NexusPackageMetadata (Join-Path $sdk 'packages/nxrtl.pcp')
$image = Read-NexusPackageImage (Join-Path $sdk 'packages/nxrtl.dll')
foreach ($record in @($metadata,$image)) {
    if ($record.Name -ine 'nxrtl' -or $record.SDK -cne $identity.SDK -or $record.Build -cne $identity.Build) {
        throw 'The nxrtl PCP/DLL pair does not match this SDK build.'
    }
}
$artifacts = @()
foreach ($file in @((Get-Item -LiteralPath $compiler)) +
    @(Get-ChildItem -LiteralPath (Join-Path $sdk 'units'),(Join-Path $sdk 'packages') -File | Sort-Object FullName)) {
    $artifacts += [ordered]@{Path=$file.FullName.Substring($sdk.Length+1);SHA256=(Get-FileHash -LiteralPath $file.FullName).Hash}
}
$version = & $compiler -iV
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the SDK compiler version.' }
[IO.File]::WriteAllText((Join-Path $sdk 'sdk.json'),
    ([ordered]@{Format=2;Target='x86_64-win64';Experimental=$true;Foundation='nxrtl';
        CompilerVersion=$version;SmartLink=$false;SDKIdentity=$identity.SDK;Artifacts=$artifacts} |
        ConvertTo-Json -Depth 5) + "`n", $encoding)
Write-Host "Package SDK ready: $sdk"
