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
    $names = @('e_plus', 'e_minus')
    if ($mode -ne 'macpas') {
        $names += @('ifopt_e_plus', 'ifopt_e_minus')
    }
    if ($mode -eq 'fpc') {
        $names += @('floating_point_emulation', 'nonsense_directive', 'ifopt_nonsense')
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
        if ($code -ne 0) {
            throw "$mode/$name was not treated as an unknown directive or switch (exit $code):`n$outputText"
        }
        Write-Host "$mode/${name}: accepted as unknown"
    }
}
