[CmdletBinding()]
param(
    [string]$SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$Compiler,
    [string]$RtlUnits,
    [string]$OutputRoot = (Join-Path $env:TEMP 'nexusprofiler-tests')
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

if (-not $Compiler) { $Compiler = Join-Path $SourceRoot 'compiler\ppcx64.exe' }
if (-not $RtlUnits) { $RtlUnits = Join-Path $SourceRoot 'rtl\units\x86_64-win64' }
$testSource = Join-Path $SourceRoot 'packages\nexusprofiler\tests'
$profileSource = Join-Path $SourceRoot 'packages\nexusprofiler\src'
$buildScript = Join-Path $SourceRoot 'packages\nexusprofiler\Build-NexusProfiler.ps1'
$llvmReadObj = (Get-Command llvm-readobj.exe -ErrorAction Stop).Source

if (Test-Path -LiteralPath $OutputRoot) {
    Remove-Item -LiteralPath $OutputRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$runtimeOutput = Join-Path $OutputRoot 'runtime'
& $buildScript -SourceRoot $SourceRoot -Compiler $Compiler `
    -RtlUnits $RtlUnits -OutputDirectory $runtimeOutput | Out-Null

$probeOutput = Join-Path $OutputRoot 'probe'
New-Item -ItemType Directory -Force -Path $probeOutput | Out-Null
& $Compiler -n "-Fu$RtlUnits" "-Fu$profileSource" "-FE$probeOutput" `
    "-FU$probeOutput" -B -O2 -Aas-clang -XLL `
    (Join-Path $testSource 'nxprofile_trace_probe.pas') | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Trace probe compilation failed' }
$traceProbe = Join-Path $probeOutput 'nxprofile_trace_probe.exe'

function Invoke-Compile {
    param(
        [string]$Source,
        [string]$Output,
        [switch]$Profile,
        [switch]$Build,
        [switch]$Release
    )
    New-Item -ItemType Directory -Force -Path $Output | Out-Null
    $arguments = @(
        '-n', "-Fu$RtlUnits", "-Fu$runtimeOutput", "-Fu$testSource",
        "-Fu$([IO.Path]::GetDirectoryName($Source))",
        "-FE$Output", "-FU$Output", '-XX', '-Aas-clang', '-XLL'
    )
    if ($Profile) { $arguments += '-profile' }
    if ($Build) { $arguments += '-B' }
    if ($Release) { $arguments += '-O2' }
    else { $arguments += @('-O-', '-g', '-gl', '-gw3') }
    $arguments += $Source
    & $Compiler @arguments | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $Source" }
}

function Read-Trace([string]$Path) {
    $values = @{}
    $lines = & $traceProbe $Path
    if ($LASTEXITCODE -ne 0) { throw "Trace probe failed: $Path" }
    foreach ($line in $lines) {
        if ($line -match '^([a-z_]+)=(\d+)$') {
            $values[$Matches[1]] = [UInt64]$Matches[2]
        }
    }
    return $values
}

function Invoke-ProfiledExe([string]$Output, [string]$Name) {
    Get-ChildItem -LiteralPath $Output -Filter 'nexus-profile-*.nxp' |
        Remove-Item -Force
    Push-Location $Output
    try {
        & (Join-Path $Output "$Name.exe") | Out-Host
        $exitCode = $LASTEXITCODE
    }
    finally { Pop-Location }
    if ($exitCode -ne 0) { throw "$Name exited with code $exitCode" }
    $traces = @(Get-ChildItem -LiteralPath $Output -Filter 'nexus-profile-*.nxp')
    Assert-True ($traces.Count -eq 1) "$Name did not produce exactly one trace"
    $values = Read-Trace $traces[0].FullName
    Assert-True ($values.truncated -eq 0) "$Name produced a truncated trace"
    Assert-True ($values.trace_end -eq 1) "$Name trace has no TRACE_END"
    Assert-True ($values.modules -ge 1) "$Name trace has no module metadata"
    Assert-True ($values.procedures -ge 1) "$Name trace has no procedure metadata"
    Assert-True ($values.events -ge 2) "$Name trace has no procedure events"
    return $values
}

Write-Host 'Format reader and writer'
& (Join-Path $SourceRoot 'tests\nexusprofiler\Run-NXProfileFormatTests.ps1') `
    -SourceRoot $SourceRoot -Compiler $Compiler -RtlUnits $RtlUnits `
    -OutputRoot (Join-Path $OutputRoot 'format') | Out-Host

Write-Host 'Activation, PPU state, and ordinary build isolation'
$activationSource = Join-Path $OutputRoot 'activation-source'
$activationOutput = Join-Path $OutputRoot 'activation'
New-Item -ItemType Directory -Force -Path $activationSource | Out-Null
@'
unit activation_unit;
{$mode objfpc}
interface
function Work: LongInt; noinline;
implementation
function Work: LongInt; begin Result := 42; end;
end.
'@ | Set-Content -LiteralPath (Join-Path $activationSource 'activation_unit.pas') -Encoding ascii
@'
program activation;
uses activation_unit;
begin if Work <> 42 then Halt(1); end.
'@ | Set-Content -LiteralPath (Join-Path $activationSource 'activation.pas') -Encoding ascii

Invoke-Compile (Join-Path $activationSource 'activation.pas') $activationOutput `
    -Profile -Build
$unitObject = Join-Path $activationOutput 'activation_unit.o'
$profileDump = & $llvmReadObj --sections --symbols $unitObject | Out-String
Assert-True ($profileDump -match 'nxp_enter') 'Profiled unit has no hook import'
$profileTime = (Get-Item -LiteralPath $unitObject).LastWriteTimeUtc
Start-Sleep -Milliseconds 1100
Invoke-Compile (Join-Path $activationSource 'activation.pas') $activationOutput
$normalDump = & $llvmReadObj --sections --symbols $unitObject | Out-String
Assert-True ($normalDump -notmatch 'nxp_enter|\.nxprof') `
    'Ordinary rebuild retained profiler data'
Assert-True ((Get-Item -LiteralPath $unitObject).LastWriteTimeUtc -gt $profileTime) `
    'Profiled PPU was reused by an ordinary build'
$normalExeDump = & $llvmReadObj --sections --symbols --coff-imports `
    (Join-Path $activationOutput 'activation.exe') | Out-String
Assert-True ($normalExeDump -notmatch `
    '\.nxprof|nxp_|__NXP_specific_handler') `
    'Ordinary executable contains profiler residue'
$normalTime = (Get-Item -LiteralPath $unitObject).LastWriteTimeUtc
Start-Sleep -Milliseconds 1100
Invoke-Compile (Join-Path $activationSource 'activation.pas') $activationOutput -Profile
$profileDump = & $llvmReadObj --sections --symbols --relocations $unitObject |
    Out-String
Assert-True ($profileDump -match 'nxp_enter') `
    'Ordinary PPU was reused by a profiling build'
Assert-True ((Get-Item -LiteralPath $unitObject).LastWriteTimeUtc -gt $normalTime) `
    'Ordinary PPU timestamp did not change for profiling'
Assert-True ($profileDump -match 'Selection: Associative') `
    'Procedure descriptor is not an associative COMDAT'
Assert-True ($profileDump -notmatch 'IMAGE_REL_AMD64_ABSOLUTE') `
    'Profiled object contains a dummy absolute relocation'
$profileExeDump = & $llvmReadObj --coff-imports `
    (Join-Path $activationOutput 'activation.exe') | Out-String
Assert-True ($profileExeDump -notmatch '(?i)nexusprofiler.*\.dll') `
    'Profiled executable imports a profiler runtime DLL'
$activationTrace = Invoke-ProfiledExe $activationOutput 'activation'
Assert-True ($activationTrace.enters -eq $activationTrace.leaves) `
    'Activation trace entry/leave counts differ'

Write-Host 'Core procedures, smartlinking, exceptions, and threads'
$smokeOutput = Join-Path $OutputRoot 'smoke'
Invoke-Compile (Join-Path $testSource 'profiler_smoke.pas') $smokeOutput `
    -Profile -Build
$smokeDump = & $llvmReadObj --sections --symbols `
    (Join-Path $smokeOutput 'profiler_smoke.exe') | Out-String
Assert-True ($smokeDump -notmatch 'UNUSEDWORK') `
    'Unused procedure survived /OPT:REF'
$smokeTrace = Invoke-ProfiledExe $smokeOutput 'profiler_smoke'
Assert-True ($smokeTrace.unwinds -ge 1) `
    'Smoke exception produced no unwind event'

$coreOutput = Join-Path $OutputRoot 'core'
Invoke-Compile (Join-Path $testSource 'profiler_core.pas') $coreOutput `
    -Profile -Build
$coreTrace = Invoke-ProfiledExe $coreOutput 'profiler_core'
Assert-True ($coreTrace.unwinds -eq 0) 'Core test unexpectedly unwound a frame'

$exceptionOutput = Join-Path $OutputRoot 'exceptions'
Invoke-Compile (Join-Path $testSource 'profiler_exceptions.pas') `
    $exceptionOutput -Profile -Build
$exceptionTrace = Invoke-ProfiledExe $exceptionOutput 'profiler_exceptions'
Assert-True ($exceptionTrace.unwinds -ge 6) `
    'Exception corpus produced too few unwind events'

$threadOutput = Join-Path $OutputRoot 'threads'
Invoke-Compile (Join-Path $testSource 'profiler_threads.pas') $threadOutput `
    -Profile -Build
$threadTrace = Invoke-ProfiledExe $threadOutput 'profiler_threads'
Assert-True ($threadTrace.threads -ge 3) `
    'Main, FPC, and foreign threads were not recorded'

Write-Host 'Release validation'
$releaseOutput = Join-Path $OutputRoot 'release'
Invoke-Compile (Join-Path $testSource 'profiler_smoke.pas') $releaseOutput `
    -Profile -Build -Release
$releaseTrace = Invoke-ProfiledExe $releaseOutput 'profiler_smoke'
$releaseDump = & $llvmReadObj --sections `
    (Join-Path $releaseOutput 'profiler_smoke.exe') | Out-String
Assert-True ($releaseDump -notmatch '\.debug_info') `
    'Release build unexpectedly contains debug information'

$optimizedOutput = Join-Path $OutputRoot 'optimized-parameters'
Invoke-Compile (Join-Path $testSource 'profiler_optimized_params.pas') `
    $optimizedOutput -Profile -Build -Release
$optimizedTrace = Invoke-ProfiledExe $optimizedOutput `
    'profiler_optimized_params'
Assert-True ($optimizedTrace.enters -eq $optimizedTrace.leaves) `
    'Optimized parameter trace entry/leave counts differ'

Write-Host 'Unhandled exception behavior'
$unhandledOutput = Join-Path $OutputRoot 'unhandled'
Invoke-Compile (Join-Path $testSource 'profiler_unhandled.pas') `
    $unhandledOutput -Profile -Build -Release
Push-Location $unhandledOutput
$savedErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    $null = & (Join-Path $unhandledOutput 'profiler_unhandled.exe') 2>&1
    $unhandledCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $savedErrorActionPreference
    Pop-Location
}
Assert-True ($unhandledCode -ne 0) `
    'Unhandled exception test unexpectedly succeeded'
$unhandledFiles = @(Get-ChildItem -LiteralPath $unhandledOutput `
    -Filter 'nexus-profile-*.nxp')
Assert-True ($unhandledFiles.Count -eq 1) `
    'Unhandled exception test did not leave exactly one trace'
$unhandledTrace = Read-Trace $unhandledFiles[0].FullName
Assert-True (($unhandledTrace.modules -ge 1) -and `
    ($unhandledTrace.procedures -ge 1) -and `
    ($unhandledTrace.truncated -eq 0) -and `
    ($unhandledTrace.unwinds -ge 1) -and `
    ($unhandledTrace.trace_end -eq 1)) `
    'Unhandled exception trace is not complete unwind evidence'

Write-Host "Nexus profiler validation passed. Artifacts: $OutputRoot"
