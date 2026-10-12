# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
<#
.SYNOPSIS
Capture one source identity and reproducible date for a Forge bootstrap.
.DESCRIPTION
Run after source staging and before compilation. Cross builds reuse these files.
Requires a Git checkout. SOURCE_DATE_EPOCH overrides the HEAD commit timestamp.
The dirty marker includes tracked changes and untracked, non-ignored files.
#>
[CmdletBinding()]
param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..'),
    [string]$OutputRoot
)
$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
if (-not $OutputRoot) { $OutputRoot = Join-Path $SourceRoot 'build/forge-bootstrap/seed' }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
$stagedSource = Join-Path $OutputRoot 'source'
if (-not (Test-Path -LiteralPath (Join-Path $stagedSource 'version.pas'))) {
    throw "Compiler source must be staged before writing its identity: $stagedSource"
}
function Read-Git([string[]]$Arguments) {
    $lines = & git -C $SourceRoot @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Git failed while capturing build identity: $Arguments" }
    return ($lines -join "`n").Trim()
}
$revision = Read-Git @('rev-parse', '--verify', 'HEAD')
$dirty = (Read-Git @('status', '--porcelain', '--untracked-files=normal')) -ne ''
$epoch = Read-Git @('show', '-s', '--format=%ct', 'HEAD')
if ($env:SOURCE_DATE_EPOCH) { $epoch = $env:SOURCE_DATE_EPOCH }
$seconds = 0L
if (-not [long]::TryParse($epoch, [ref]$seconds) -or $seconds -lt 0) {
    throw 'SOURCE_DATE_EPOCH/commit timestamp must be non-negative integer seconds.'
}
$timestamp = [DateTimeOffset]::FromUnixTimeSeconds($seconds).UtcDateTime
$date = $timestamp.ToString('yyyy/MM/dd', [Globalization.CultureInfo]::InvariantCulture)
$time = $timestamp.ToString('HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
$identity = $revision
if ($dirty) { $identity += '-dirty' }
$encoding = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $stagedSource 'revision.inc'), "'$identity'`n", $encoding)
[IO.File]::WriteAllText((Join-Path $OutputRoot 'build-options.cfg'), "-DD$date`n-DT$time`n", $encoding)
$record = [ordered]@{ Revision=$revision; Dirty=$dirty; Identity=$identity; Date=$date; Time=$time; SourceDateEpoch=$seconds }
[IO.File]::WriteAllText((Join-Path $OutputRoot 'build-identity.json'), ($record | ConvertTo-Json) + "`n", $encoding)
Write-Host "Build identity: $identity; compiler date: $date $time UTC"
