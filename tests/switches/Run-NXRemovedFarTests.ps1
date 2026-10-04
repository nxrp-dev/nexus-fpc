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

foreach ($name in @('removed_f_plus', 'removed_f_minus', 'removed_farcalls')) {
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

foreach ($name in @('removed_far_procedure', 'removed_near_procedure', 'removed_far_pointer_win64')) {
    $source = Join-Path $PSScriptRoot ($name + '.pas')
    $arguments = @('-n', '-Twin64', ('-Fu' + $RtlUnits),
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
        throw "$name was not rejected (exit $code):`n$outputText"
    }
    Write-Host "${name}: rejected as expected"
}
