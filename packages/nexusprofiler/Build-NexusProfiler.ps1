[CmdletBinding()]
param(
    [string]$SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$Compiler,
    [string]$RtlUnits,
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

if (-not $Compiler) {
    $Compiler = Join-Path $SourceRoot 'compiler\ppcx64.exe'
}
if (-not $RtlUnits) {
    $RtlUnits = Join-Path $SourceRoot 'rtl\units\x86_64-win64'
}

foreach ($path in @($Compiler, $RtlUnits)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required NexusFPC build input is missing: $path"
    }
}
foreach ($tool in @('clang.exe', 'lld-link.exe')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Required LLVM tool is not on PATH: $tool"
    }
}

$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$profileSource = Join-Path $PSScriptRoot 'src'
$runtime = Join-Path $profileSource 'NXProfilerRuntime.pas'
$common = @(
    '-n',
    "-Fu$RtlUnits",
    "-Fu$profileSource",
    "-FE$OutputDirectory",
    "-FU$OutputDirectory",
    '-B',
    '-O2',
    '-profile',
    '-Aas-clang',
    '-XLL'
)

& $Compiler @common $runtime
if ($LASTEXITCODE -ne 0) {
    throw "Profiler runtime build failed with exit code $LASTEXITCODE"
}

Write-Output (Join-Path $OutputDirectory 'nxprofilerruntime.ppu')
