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
$source = Join-Path $PSScriptRoot 'removed_legacy_options_baseline.pas'
$directiveSource = Join-Path $PSScriptRoot 'removed_checklowaddrloads.pas'

$arguments = @('-n', '-Twin64', '-vw', ('-Fu' + $RtlUnits),
    ('-FU' + $OutputRoot), ('-FE' + $OutputRoot), $directiveSource)
$ErrorActionPreference = 'Continue'
try {
    $compilerOutput = @(& $CompilerPath @arguments 2>&1 | ForEach-Object { $_.ToString() })
    $code = $LASTEXITCODE
} finally {
    $ErrorActionPreference = 'Stop'
}
$outputText = $compilerOutput -join "`n"
if ($code -ne 0 -or $outputText -notmatch '(?i)Warning:.*(unknown|illegal|unrecognized)') {
    throw "CHECKLOWADDRLOADS did not follow the unknown-directive path (exit $code):`n$outputText"
}
Write-Host 'CHECKLOWADDRLOADS: unknown directive warning as expected'

foreach ($option in @('-CD', '-CN', '-Xf', '-Xn', '-Xu', '-xignored', '-bl',
        '-Fg', '-Up', '-Og', '-OG', '-Or', '-Ou', '-St',
        '-CTSMALLTOC', '-CTCOMPACTINTARRAYINIT', '-CTENUMFIELDINIT',
        '-CTTHUMBINTERWORKING', '-CTINITLOCALS', '-CTFARPROCSPUSHODDBP',
        '-CTNOEXCEPTIONS', '-CTBFEXCEPTIONS', '-CTWASMEXCEPTIONS',
        '-CTLEGACYEXCEPTIONS', '-CTWASMTHREADS', '-CTSATURATINGFLOATTOINT')) {
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
    if ($code -eq 0 -or $outputText -notmatch '(?i)Error:\s*Illegal parameter:') {
        throw "$option did not follow the unknown-option path (exit $code):`n$outputText"
    }
    Write-Host "${option}: rejected as an illegal parameter"
}

foreach ($option in @('-b', '-b-', '-CTCLD', '-CTCLD-', '-CTLOWERCASEPROCSTART')) {
    $arguments = @('-n', '-Twin64', $option, ('-Fu' + $RtlUnits),
        ('-FU' + $OutputRoot), ('-FE' + $OutputRoot), $source)
    $ErrorActionPreference = 'Continue'
    try {
        $compilerOutput = @(& $CompilerPath @arguments 2>&1 | ForEach-Object { $_.ToString() })
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = 'Stop'
    }
    if ($code -ne 0) {
        throw "$option no longer compiles (exit $code):`n$($compilerOutput -join "`n")"
    }
    Write-Host "${option}: retained as expected"
}

$directiveSource = Join-Path $PSScriptRoot 'removed_target_switches.pas'
$arguments = @('-n', '-Twin64', '-vw', ('-Fu' + $RtlUnits),
    ('-FU' + $OutputRoot), ('-FE' + $OutputRoot), $directiveSource)
$ErrorActionPreference = 'Continue'
try {
    $compilerOutput = @(& $CompilerPath @arguments 2>&1 | ForEach-Object { $_.ToString() })
    $code = $LASTEXITCODE
} finally {
    $ErrorActionPreference = 'Stop'
}
$outputText = $compilerOutput -join "`n"
if ($code -ne 0) { throw "Removed target-switch directives failed unexpectedly:`n$outputText" }
foreach ($name in @('SMALLTOC', 'COMPACTINTARRAYINIT', 'ENUMFIELDINIT',
        'THUMBINTERWORKING', 'INITLOCALS', 'FARPROCSPUSHODDBP',
        'NOEXCEPTIONS', 'BFEXCEPTIONS', 'WASMEXCEPTIONS',
        'LEGACYEXCEPTIONS', 'WASMTHREADS', 'SATURATINGFLOATTOINT')) {
    if ($outputText -notmatch ('(?i)Warning:.*Illegal compiler switch "' + $name + '"')) {
        throw "Missing unknown-directive warning for ${name}:`n$outputText"
    }
}
Write-Host 'Retired target-switch directives warn and leave no obsolete feature macros defined'
