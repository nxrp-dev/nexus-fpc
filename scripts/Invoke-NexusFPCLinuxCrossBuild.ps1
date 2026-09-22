<#
.SYNOPSIS
Build Windows-hosted NexusFPC compilers for the retained Linux CPU targets.
.DESCRIPTION
Builds separate ppcrossx64.exe and ppcrossa64.exe binaries from the repository's
native x86-64 Windows compiler. Invoke them with -Tlinux to select Linux output.
The optional RTL build requires Linux cross binutils for each selected CPU.
.EXAMPLE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-NexusFPCLinuxCrossBuild.ps1
.EXAMPLE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-NexusFPCLinuxCrossBuild.ps1 -TargetCpu aarch64 -BuildRTL -BinutilsDir C:\cross\bin
#>
[CmdletBinding()]
param(
    [ValidateSet('x86_64', 'aarch64')]
    [string[]]$TargetCpu = @('x86_64', 'aarch64'),
    [string]$SourceRoot,
    [string]$MakeBin = 'C:\lazarus\fpc\3.2.2\bin\x86_64-win64',
    [string]$HostCompiler,
    [string]$BinutilsDir,
    [string]$LogRoot = (Join-Path $env:TEMP 'NexusFPCLinuxCrossBuild'),
    [switch]$BuildRTL
)

$ErrorActionPreference = 'Stop'
if (-not $SourceRoot) { $SourceRoot = Join-Path $PSScriptRoot '..' }
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$MakeBin = (Resolve-Path -LiteralPath $MakeBin).Path
if (-not $HostCompiler) { $HostCompiler = Join-Path $SourceRoot 'compiler\ppcx64.exe' }
$HostCompiler = (Resolve-Path -LiteralPath $HostCompiler).Path
$make = Join-Path $MakeBin 'make.exe'
if (-not (Test-Path -LiteralPath $make)) { throw "GNU make is missing: $make" }
if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot 'compiler\pp.pas'))) {
    throw "NexusFPC compiler source is missing under $SourceRoot"
}
if ((& $HostCompiler -iTP) -ne 'x86_64' -or $LASTEXITCODE -ne 0 -or
    (& $HostCompiler -iTO) -ne 'win64' -or $LASTEXITCODE -ne 0) {
    throw 'The host compiler must run on x86_64-win64.'
}
if ($BinutilsDir) { $BinutilsDir = (Resolve-Path -LiteralPath $BinutilsDir).Path }

$oldPath = $env:PATH
try {
    $pathParts = @($MakeBin)
    if ($BinutilsDir) { $pathParts += $BinutilsDir }
    $env:PATH = ($pathParts -join ';') + ';' + $oldPath

    if ($BuildRTL) {
        foreach ($cpu in $TargetCpu) {
            foreach ($tool in @("$cpu-linux-as.exe", "$cpu-linux-ld.exe")) {
                if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
                    throw "Linux RTL build requires $tool on PATH. Supply -BinutilsDir if it is installed elsewhere."
                }
            }
        }
    }

    $runRoot = Join-Path ([IO.Path]::GetFullPath($LogRoot)) ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $runRoot -Force | Out-Null

    function Invoke-MakeStep([string]$Name, [string[]]$Arguments) {
        $log = Join-Path $runRoot "$Name.log"
        Write-Host "Building $Name. Log: $log"
        $ErrorActionPreference = 'Continue'
        try {
            & $make @Arguments *> $log
            $code = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = 'Stop'
        }
        if ($code -ne 0) {
            Get-Content -LiteralPath $log -Tail 20 | Write-Host
            throw "$Name failed with exit code $code. See $log"
        }
    }

    foreach ($cpu in $TargetCpu) {
        $suffix = if ($cpu -eq 'x86_64') { 'x64' } else { 'a64' }
        $compilerName = "ppcross$suffix.exe"
        $compiler = Join-Path $SourceRoot "compiler\$compilerName"
        $common = @(
            "FPC=$($HostCompiler -replace '\\', '/')",
            'CPU_TARGET=x86_64', 'OS_TARGET=win64',
            "PPC_TARGET=$cpu", "CPU_UNITDIR=$($cpu)_cross"
        )
        Invoke-MakeStep "compiler-$cpu-linux" (@('-B', '-C', (Join-Path $SourceRoot 'compiler'), 'compiler') + $common + "EXENAME=$compilerName")
        if (-not (Test-Path -LiteralPath $compiler) -or
            (& $compiler -Tlinux -iTP) -ne $cpu -or $LASTEXITCODE -ne 0 -or
            (& $compiler -Tlinux -iTO) -ne 'linux' -or $LASTEXITCODE -ne 0) {
            throw "$compiler did not report $cpu-linux."
        }
        Write-Host "Ready: $compiler -Tlinux ($cpu-linux)"

        if ($BuildRTL) {
            Invoke-MakeStep "rtl-$cpu-linux" (@('-C', (Join-Path $SourceRoot 'rtl'), 'all',
                "FPC=$($compiler -replace '\\', '/')", "CPU_TARGET=$cpu", 'OS_TARGET=linux'))
            $systemUnit = Join-Path $SourceRoot "rtl\units\$cpu-linux\system.ppu"
            if (-not (Test-Path -LiteralPath $systemUnit)) { throw "RTL build did not produce $systemUnit" }
            Write-Host "RTL ready: $systemUnit"
        }
    }
    Write-Host "Build logs: $runRoot"
} finally {
    $env:PATH = $oldPath
}
