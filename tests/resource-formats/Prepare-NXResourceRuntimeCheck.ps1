[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Compiler,
    [Parameter(Mandatory = $true)][string]$RtlUnits,
    [Parameter(Mandatory = $true)][ValidateSet('win32', 'win64')][string]$TargetOS,
    [Parameter(Mandatory = $true)][string]$FixtureRes,
    [Parameter(Mandatory = $true)][string]$ArtifactRoot,
    [string]$SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string[]]$CompilerArguments = @()
)
$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$Compiler = (Get-Command $Compiler -ErrorAction Stop).Source
$RtlUnits = (Resolve-Path -LiteralPath $RtlUnits).Path
$FixtureRes = (Resolve-Path -LiteralPath $FixtureRes).Path
$ArtifactRoot = [IO.Path]::GetFullPath($ArtifactRoot)
if ($ArtifactRoot.StartsWith($SourceRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase) -or $ArtifactRoot -eq $SourceRoot) {
    throw 'Use an output directory outside the source tree.'
}
$units = Join-Path $ArtifactRoot 'units'
$logs = Join-Path $ArtifactRoot 'logs'
New-Item -ItemType Directory -Force -Path $units, $logs | Out-Null
Copy-Item -LiteralPath $FixtureRes -Destination (Join-Path $ArtifactRoot 'runtimetables.res')
Copy-Item -LiteralPath (Join-Path $SourceRoot 'tests/resource-formats/nxResourceRuntimeTests.pas') -Destination $ArtifactRoot
$executable = Join-Path $ArtifactRoot 'nxResourceRuntimeTests.exe'
$arguments = @('-n', '-al', '-O2', '-Cr', '-Co', '-Ci', '-Aas-clang', '-XLL',
    "-T$TargetOS", "-Fu$RtlUnits", "-Fu$(Join-Path $SourceRoot 'compiler')",
    "-FU$units", "-FE$ArtifactRoot", "-o$executable")
$arguments += $CompilerArguments
$arguments += (Join-Path $ArtifactRoot 'nxResourceRuntimeTests.pas')
[ordered]@{ Compiler = $Compiler; Arguments = $arguments } | ConvertTo-Json -Depth 5 |
    Set-Content -Encoding UTF8 (Join-Path $logs 'compiler-command.json')
Push-Location $ArtifactRoot
try {
    $ErrorActionPreference = 'Continue'
    & $Compiler @arguments > (Join-Path $logs 'compile.log') 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($code -ne 0) { throw "Compiler failed ($code); preserve $logs for analysis." }
    if (-not (Test-Path -LiteralPath $executable)) { throw "Missing executable: $executable" }
} finally { Pop-Location }
Write-Host "Prepared $executable through the integrated compiler resource path."
