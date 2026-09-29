[CmdletBinding()]
param(
    [string]$Compiler = 'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\ppcx64.exe',
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not $OutputPath) {
    $OutputPath = Join-Path $env:TEMP 'NexusModuleFoundationTests'
}

$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
$output = (Resolve-Path -LiteralPath $OutputPath).Path

$arguments = @(
    '-B',
    '-Mobjfpc',
    '-gl',
    '-gh',
    '-Cr',
    '-Co',
    '-Ci',
    '-Sa',
    "-Fu$root",
    "-Fu$(Join-Path $root 'nexus_pascal_tokenizer')",
    "-FU$output",
    "-FE$output",
    (Join-Path $root 'nxmodule_tests.pas')
)

& $compilerPath @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Test compilation failed with exit code $LASTEXITCODE"
}

$testExecutable = Join-Path $output 'nxmodule_tests.exe'
& $testExecutable
if ($LASTEXITCODE -ne 0) {
    throw "Tests failed with exit code $LASTEXITCODE"
}

Write-Host "Tests passed: $testExecutable"
