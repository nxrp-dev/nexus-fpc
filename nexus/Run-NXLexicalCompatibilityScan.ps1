[CmdletBinding()]
param(
    [string]$Compiler = 'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\ppcx64.exe',
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$repositoryRoot = Split-Path -Parent $root

if (-not $OutputPath) {
    $OutputPath = Join-Path $env:TEMP 'NexusLexicalCompatibility'
}

$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
$output = (Resolve-Path -LiteralPath $OutputPath).Path

$arguments = @(
    '-B',
    '-Mobjfpc',
    '-gl',
    '-Cr',
    '-Co',
    '-Ci',
    '-Sa',
    "-Fu$(Join-Path $root 'nexus_pascal_tokenizer')",
    "-FU$output",
    "-FE$output",
    (Join-Path $root 'nxlexical_compat_scan.pas')
)

& $compilerPath @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Compatibility scanner compilation failed with exit code $LASTEXITCODE"
}

$scanRoots = @(
    (Join-Path $repositoryRoot 'compiler'),
    (Join-Path $repositoryRoot 'rtl')
)
$scanRoots += Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'packages') -Directory -Filter 'fcl-*' |
    Select-Object -ExpandProperty FullName

$scanner = Join-Path $output 'nxlexical_compat_scan.exe'
& $scanner @scanRoots
if ($LASTEXITCODE -ne 0) {
    throw "Compatibility scan failed with exit code $LASTEXITCODE"
}
