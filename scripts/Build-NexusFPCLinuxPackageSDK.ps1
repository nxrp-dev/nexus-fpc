<#
.SYNOPSIS
Build the experimental Linux glibc package SDK and optionally execute its tests in WSL.
.EXAMPLE
.\scripts\Build-NexusFPCLinuxPackageSDK.ps1 -OutputRoot /var/tmp/nexus-linux-sdk -RunTests
#>
[CmdletBinding()]
param(
    [string]$SourceRoot,
    [Parameter(Mandatory=$true)][string]$OutputRoot,
    [string]$Distribution = 'Ubuntu',
    [switch]$SmartLink,
    [switch]$RunTests
)
trap { Write-Output ('ERROR: ' + $_.Exception.Message); exit 1 }
$ErrorActionPreference = 'Stop'
if (-not $SourceRoot) { $SourceRoot = Join-Path $PSScriptRoot '..' }
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
function ConvertTo-LinuxPath([string]$Path) {
    if ($Path.StartsWith('/')) { return $Path }
    $full = [IO.Path]::GetFullPath($Path)
    if ($full -notmatch '^([A-Za-z]):\\(.*)$') { throw "Use a drive path or Linux absolute path: $Path" }
    return '/mnt/' + $Matches[1].ToLowerInvariant() + '/' + $Matches[2].Replace('\','/')
}
function Invoke-LinuxPackageStep([string[]]$CommandArguments, [string]$Failure) {
    $ErrorActionPreference = 'Continue'
    # Keep native diagnostics readable and judge success by the process exit
    # code, including when WSL writes a warning to stderr on a successful run.
    & wsl.exe @CommandArguments 2>&1 | ForEach-Object { Write-Output $_.ToString() }
    if ($LASTEXITCODE -ne 0) { throw $Failure }
}
$linuxSource = ConvertTo-LinuxPath $SourceRoot
$linuxOutput = ConvertTo-LinuxPath $OutputRoot
$arguments = @('-d',$Distribution,'--','python3',"$linuxSource/scripts/build_linux_package_sdk.py",
    '--source-root',$linuxSource,'--output-root',$linuxOutput)
if ($SmartLink) { $arguments += '--smart' }
Invoke-LinuxPackageStep $arguments 'Linux package SDK build failed. See its logs directory.'
if ($RunTests) {
    $arguments = @('-d',$Distribution,'--','python3',"$linuxSource/tests/dynamic-packages/run_linux_package_tests.py",
        '--sdk',$linuxOutput)
    if ($SmartLink) { $arguments += '--smart' }
    Invoke-LinuxPackageStep $arguments 'Linux package runtime tests failed. See the reported test directory.'
}
