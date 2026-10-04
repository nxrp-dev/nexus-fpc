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

foreach ($mode in @('fpc', 'objfpc', 'macpas')) {
    $names = @('g_plus', 'g_minus')
    if ($mode -eq 'macpas') {
        $names += 'mac_option_g'
    } else {
        $names += @('ifopt_g_plus', 'ifopt_g_minus')
    }
    foreach ($name in $names) {
        $source = Join-Path $PSScriptRoot ($name + '.pas')
        $arguments = @('-n', '-Twin64', ('-M' + $mode), ('-Fu' + $RtlUnits),
            ('-FU' + $OutputRoot), ('-FE' + $OutputRoot), $source)
        $ErrorActionPreference = 'Continue'
        try {
            $compilerOutput = @(& $CompilerPath @arguments 2>&1 | ForEach-Object { $_.ToString() })
            $code = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = 'Stop'
        }
        $outputText = $compilerOutput -join "`n"
        if ($code -eq 0 -or $outputText -notmatch '(?i)Error:.*Illegal compiler directive') {
            throw "$mode/$name did not produce the expected illegal-directive error (exit $code):`n$outputText"
        }
        Write-Host "$mode/${name}: rejected as expected"
    }
}
