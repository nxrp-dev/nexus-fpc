[CmdletBinding()]
param(
    [string]$SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$Compiler,
    [string]$RtlUnits,
    [string]$OutputRoot = (Join-Path $env:TEMP 'nxprofile-format-tests')
)

$ErrorActionPreference = 'Stop'
if (-not $Compiler) { $Compiler = Join-Path $SourceRoot 'compiler\ppcx64.exe' }
if (-not $RtlUnits) { $RtlUnits = Join-Path $SourceRoot 'rtl\units\x86_64-win64' }
$unitSource = Join-Path $SourceRoot 'packages\nexusprofiler\src'
$testSource = Join-Path $SourceRoot `
    'packages\nexusprofiler\tests\nxprofile_format_test.pas'

if (Test-Path -LiteralPath $OutputRoot) {
    Remove-Item -LiteralPath $OutputRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputRoot | Out-Null

& $Compiler -n "-Fu$RtlUnits" "-Fu$unitSource" "-FE$OutputRoot" `
    "-FU$OutputRoot" -B -O2 -Cr -Co -Aas-clang -XLL $testSource | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "NXProfile format test compilation failed with exit code $LASTEXITCODE"
}

& (Join-Path $OutputRoot 'nxprofile_format_test.exe') | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "NXProfile format tests failed with exit code $LASTEXITCODE"
}

$eventMemoryTest = Join-Path $SourceRoot `
    'packages\nexusprofiler\tests\nxeventmemory_test.pas'
& $Compiler -n "-Fu$RtlUnits" "-Fu$unitSource" "-FE$OutputRoot" `
    "-FU$OutputRoot" -B -O2 -Cr -Co -Aas-clang -XLL $eventMemoryTest | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "NXEventMemory test compilation failed with exit code $LASTEXITCODE"
}

& (Join-Path $OutputRoot 'nxeventmemory_test.exe') | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "NXEventMemory tests failed with exit code $LASTEXITCODE"
}

Write-Host "NXProfile format validation passed. Artifacts: $OutputRoot"
