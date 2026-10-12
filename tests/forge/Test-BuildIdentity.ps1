# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputRoot)
$ErrorActionPreference = 'Stop'
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $OutputRoot) { throw 'Use a new output directory for the identity fixture.' }
$fixture = Join-Path $OutputRoot 'repository'
$staged = Join-Path $fixture 'build/forge-bootstrap/seed/source'
New-Item -ItemType Directory -Path $staged -Force | Out-Null
$writer = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../scripts/Write-NexusFPCBuildIdentity.ps1'))
$identityFile = Join-Path $fixture 'build/forge-bootstrap/seed/build-identity.json'
$oldEpoch = $env:SOURCE_DATE_EPOCH
function Invoke-Git([string[]]$Arguments) {
    & git -C $fixture @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Fixture Git operation failed: $Arguments" }
}
function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
try {
    Set-Content -LiteralPath (Join-Path $staged 'version.pas') -Value 'unit version;'
    Set-Content -LiteralPath (Join-Path $fixture '.gitignore') -Value '/build/'
    Set-Content -LiteralPath (Join-Path $fixture 'input.pas') -Value 'original'
    Invoke-Git @('init', '-q')
    Invoke-Git @('add', '.')
    Invoke-Git @('-c','user.name=Identity Test','-c','user.email=identity@example.invalid','-c','commit.gpgSign=false','commit','-qm','Fixture')
    $env:SOURCE_DATE_EPOCH = '946684800'
    & $writer -SourceRoot $fixture
    $identity = Get-Content -LiteralPath $identityFile -Raw | ConvertFrom-Json
    Assert (-not $identity.Dirty) 'Clean checkout was marked dirty.'
    Assert ($identity.Identity -eq $identity.Revision) 'Clean identity differs from revision.'
    Assert ($identity.Date -eq '2000/01/01' -and $identity.Time -eq '00:00:00') 'SOURCE_DATE_EPOCH was not applied in UTC.'
    $options = Get-Content -LiteralPath (Join-Path $fixture 'build/forge-bootstrap/seed/build-options.cfg') -Raw
    Assert ($options.Contains('-DD2000/01/01') -and $options.Contains('-DT00:00:00')) 'Fixed compiler options missing.'
    $hash = (Get-FileHash -LiteralPath $identityFile).Hash
    & $writer -SourceRoot $fixture
    Assert ((Get-FileHash -LiteralPath $identityFile).Hash -eq $hash) 'Repeated capture changed a fixed identity.'
    Set-Content -LiteralPath (Join-Path $fixture 'input.pas') -Value 'modified'
    & $writer -SourceRoot $fixture
    $identity = Get-Content -LiteralPath $identityFile -Raw | ConvertFrom-Json
    Assert ($identity.Dirty -and $identity.Identity.EndsWith('-dirty')) 'Tracked changes were missed.'
    Invoke-Git @('restore', 'input.pas')
    Set-Content -LiteralPath (Join-Path $fixture 'new.pas') -Value 'untracked source'
    & $writer -SourceRoot $fixture
    $identity = Get-Content -LiteralPath $identityFile -Raw | ConvertFrom-Json
    Assert $identity.Dirty 'Untracked source was missed.'
    $hash = (Get-FileHash -LiteralPath $identityFile).Hash
    $env:SOURCE_DATE_EPOCH = 'invalid'
    $rejected = $false
    try { & $writer -SourceRoot $fixture } catch { $rejected = $true }
    Assert $rejected 'Invalid epoch was accepted.'
    Assert ((Get-FileHash -LiteralPath $identityFile).Hash -eq $hash) 'Invalid epoch overwrote captured identity.'
    $env:SOURCE_DATE_EPOCH = $null
    & $writer -SourceRoot $fixture
    $identity = Get-Content -LiteralPath $identityFile -Raw | ConvertFrom-Json
    $epoch = & git -C $fixture show -s --format=%ct HEAD
    $expectedDate = [DateTimeOffset]::FromUnixTimeSeconds([long]$epoch).UtcDateTime.ToString('yyyy/MM/dd')
    Assert ($identity.Date -eq $expectedDate) 'Default date did not come from HEAD.'
    Write-Host 'PASS clean, dirty, untracked, fixed epoch, repeatability, invalid epoch, commit date'
} finally {
    $env:SOURCE_DATE_EPOCH = $oldEpoch
}

