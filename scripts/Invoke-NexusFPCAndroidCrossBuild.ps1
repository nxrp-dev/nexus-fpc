<#
.SYNOPSIS
Build Windows-hosted NexusFPC cross compilers and Android RTLs using NDK Clang.
.DESCRIPTION
The shared CPU cross compilers also support Linux. Android startup assembly uses
android-clang.mk as an overlay; generated Makefile and Makefile.fpc are untouched.
#>
[CmdletBinding()]
param(
    [ValidateSet('x86_64', 'aarch64')]
    [string[]]$TargetCpu = @('x86_64', 'aarch64'),
    [Parameter(Mandatory = $true)]
    [string]$NdkRoot,
    [string]$SourceRoot,
    [string]$MakeBin = 'C:\lazarus\fpc\3.2.2\bin\x86_64-win64',
    [string]$LogRoot = (Join-Path $env:TEMP 'NexusFPCAndroidCrossBuild')
)

$ErrorActionPreference = 'Stop'
if (-not $SourceRoot) { $SourceRoot = Join-Path $PSScriptRoot '..' }
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$NdkRoot = (Resolve-Path -LiteralPath $NdkRoot).Path
$toolBin = Join-Path $NdkRoot 'toolchains\llvm\prebuilt\windows-x86_64\bin'
$make = Join-Path $MakeBin 'make.exe'
foreach ($file in @($make, (Join-Path $toolBin 'clang.exe'))) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Required tool is missing: $file" }
}

& (Join-Path $PSScriptRoot 'Invoke-NexusFPCLinuxCrossBuild.ps1') `
    -SourceRoot $SourceRoot -TargetCpu $TargetCpu -MakeBin $MakeBin -LogRoot $LogRoot

$runRoot = Join-Path ([IO.Path]::GetFullPath($LogRoot)) ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$oldPath = $env:PATH
try {
    $env:PATH = "$toolBin;$MakeBin;$oldPath"
    foreach ($cpu in $TargetCpu) {
        $suffix = if ($cpu -eq 'x86_64') { 'x64' } else { 'a64' }
        $compiler = (Join-Path $SourceRoot "compiler\ppcross$suffix.exe") -replace '\\', '/'
        if ((& $compiler -Tandroid -iTP) -ne $cpu -or $LASTEXITCODE -ne 0 -or
            (& $compiler -Tandroid -iTO) -ne 'android' -or $LASTEXITCODE -ne 0) {
            throw "$compiler did not report $cpu-android."
        }
        $arguments = @(
            '-C', (Join-Path $SourceRoot 'rtl\android'),
            '-f', (Join-Path $PSScriptRoot 'android-clang.mk'),
            "FPC=$compiler", "CPU_TARGET=$cpu", 'OS_TARGET=android',
            'BINUTILSPREFIX=', 'ASPROG=clang', 'RELEASE=1',
            "ASTARGET=--target=$cpu-linux-android -c -x assembler",
            'OPT=-n -Cg'
        )
        foreach ($step in @('clean', 'all')) {
            $log = Join-Path $runRoot "rtl-$cpu-android-$step.log"
            Write-Host "Starting Android $cpu RTL $step. Log: $log"
            $ErrorActionPreference = 'Continue'
            try {
                & $make @arguments $step *> $log
                $code = $LASTEXITCODE
            } finally { $ErrorActionPreference = 'Stop' }
            if ($code -ne 0) {
                Get-Content -LiteralPath $log -Tail 20 | Write-Host
                throw "Android $cpu RTL $step failed with exit $code. See $log"
            }
        }
        $systemUnit = Join-Path $SourceRoot "rtl\units\$cpu-android\system.ppu"
        if (-not (Test-Path -LiteralPath $systemUnit)) { throw "Missing RTL output: $systemUnit" }
        Write-Host "RTL ready: $systemUnit"
    }
    Write-Host "Build logs: $runRoot"
} finally { $env:PATH = $oldPath }
