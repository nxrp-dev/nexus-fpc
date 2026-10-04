param(
    [Parameter(Mandatory)][string]$CompilerPath,
    [Parameter(Mandatory)][string]$RtlUnits,
    [Parameter(Mandatory)][string]$OutputRoot
)

$ErrorActionPreference = 'Stop'
$CompilerPath = (Resolve-Path -LiteralPath $CompilerPath).Path
$RtlUnits = (Resolve-Path -LiteralPath $RtlUnits).Path
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path

foreach ($name in @('removed_n_plus', 'removed_n_minus')) {
    $source = Join-Path $PSScriptRoot ($name + '.pas')
    $arguments = @('-n', '-Twin64', '-vw', ('-Fu' + $RtlUnits),
        ('-FU' + $OutputRoot), ('-FE' + $OutputRoot), $source)
    $ErrorActionPreference = 'Continue'
    try {
        $compilerOutput = @(& $CompilerPath @arguments 2>&1 | ForEach-Object { $_.ToString() })
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = 'Stop'
    }
    $outputText = $compilerOutput -join "`n"
    if ($code -ne 0 -or $outputText -notmatch '(?i)Warning:.*(unknown|illegal|unrecognized)') {
        throw "$name did not follow the unknown-directive warning path (exit $code):`n$outputText"
    }
    Write-Host "${name}: unknown directive warning as expected"
}

$source = Join-Path $PSScriptRoot 'removed_legacy_options_baseline.pas'
foreach ($option in @('-a5', '-a5-')) {
    $arguments = @('-n', '-Twin64', $option, ('-Fu' + $RtlUnits),
        ('-FU' + $OutputRoot), ('-FE' + $OutputRoot), $source)
    $ErrorActionPreference = 'Continue'
    try {
        $compilerOutput = @(& $CompilerPath @arguments 2>&1 | ForEach-Object { $_.ToString() })
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = 'Stop'
    }
    $outputText = $compilerOutput -join "`n"
    if ($code -eq 0 -or $outputText -notmatch '(?i)(Error|Fatal):') {
        throw "$option was not rejected (exit $code):`n$outputText"
    }
    Write-Host "${option}: rejected as expected"
}
