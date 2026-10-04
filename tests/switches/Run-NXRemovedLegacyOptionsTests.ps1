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

$baseline = Join-Path $PSScriptRoot 'removed_legacy_options_baseline.pas'
$modeSource = Join-Path $PSScriptRoot 'removed_tp_mode.pas'
$namesSource = Join-Path $PSScriptRoot 'removed_ss_names.pas'
$arguments = @('-n', '-Twin64', ('-Fu' + $RtlUnits),
    ('-FU' + $OutputRoot), ('-FE' + $OutputRoot), $namesSource)
$ErrorActionPreference = 'Continue'
try {
    $compilerOutput = @(& $CompilerPath @arguments 2>&1 | ForEach-Object { $_.ToString() })
    $code = $LASTEXITCODE
} finally {
    $ErrorActionPreference = 'Stop'
}
if ($code -ne 0) {
    throw "Arbitrarily named constructor/destructor did not compile (exit $code):`n$($compilerOutput -join "`n")"
}
Write-Host 'Arbitrarily named constructor/destructor: compiled as expected'

$cases = @(
    @{ Name = 'Mtp'; Option = '-Mtp'; Source = $baseline },
    @{ Name = 'So'; Option = '-So'; Source = $baseline },
    @{ Name = 'Sk'; Option = '-Sk'; Source = $baseline },
    @{ Name = 'Ss'; Option = '-Ss'; Source = $baseline },
    @{ Name = 'MODE TP'; Option = $null; Source = $modeSource }
)

foreach ($case in $cases) {
    $arguments = @('-n', '-Twin64', '-vw', ('-Fu' + $RtlUnits),
        ('-FU' + $OutputRoot), ('-FE' + $OutputRoot))
    if ($case.Option) { $arguments += $case.Option }
    $arguments += $case.Source
    $ErrorActionPreference = 'Continue'
    try {
        $compilerOutput = @(& $CompilerPath @arguments 2>&1 | ForEach-Object { $_.ToString() })
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = 'Stop'
    }
    $outputText = $compilerOutput -join "`n"
    if ($case.Name -eq 'MODE TP') {
        if ($code -ne 0 -or $outputText -notmatch '(?i)Warning: Illegal compiler switch "TP"') {
            throw "MODE TP did not follow the unknown-mode warning path (exit $code):`n$outputText"
        }
    } elseif ($code -eq 0 -or $outputText -notmatch '(?i)(Error|Fatal):') {
        throw "$($case.Name) was not rejected (exit $code):`n$outputText"
    }
    Write-Host "$($case.Name): handled as expected"
}
