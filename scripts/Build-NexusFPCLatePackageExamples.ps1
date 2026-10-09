<#
.SYNOPSIS
Build and optionally run the late-load console/GUI package examples with an SDK.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SdkRoot,
    [Parameter(Mandatory=$true)][string]$OutputRoot,
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..'),
    [switch]$SmartLink,
    [switch]$RunExamples
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'NexusFPCPackageArtifacts.ps1')
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$SdkRoot = (Resolve-Path -LiteralPath $SdkRoot).Path
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if ((Test-Path -LiteralPath $OutputRoot) -and (Get-ChildItem -LiteralPath $OutputRoot -Force)) {
    throw 'OutputRoot must be new or empty.'
}
$rc = (Get-Command llvm-rc.exe -ErrorAction Stop).Source
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$source = Join-Path $OutputRoot 'source'
Copy-Item -LiteralPath "$SourceRoot\examples\dynamic-packages\late" -Destination $source -Recurse
$rcLog = Join-Path $OutputRoot 'resources.log'
Push-Location "$source\base"
try {
    $ErrorActionPreference = 'Continue'
    & $rc /fo pluginbase.res pluginbase.rc *> $rcLog
    $code = $LASTEXITCODE
} finally { Pop-Location; $ErrorActionPreference = 'Stop' }
if ($code -ne 0) { throw "Resource compilation failed ($code). See $rcLog" }
$packages = Join-Path $OutputRoot 'packages'
New-Item -ItemType Directory -Path $packages | Out-Null
$compile = Join-Path $PSScriptRoot 'Invoke-NexusFPCPackageCompile.ps1'
foreach ($item in @(@('contracts','democontracts'),@('base','pluginbase'),@('left','pluginleft'),@('right','pluginright'))) {
    & $compile -SdkRoot $SdkRoot -Kind Package -Source "$source\$($item[0])\$($item[1]).ppk" `
        -PackagePath $packages -OutputDirectory $packages -SmartLink:$SmartLink
}
foreach ($kind in @('Console','GUI')) {
    $name = 'late_'+$kind.ToLowerInvariant()
    & $compile -SdkRoot $SdkRoot -Kind $kind -Source "$source\host\$name.pas" `
        -RequiredPackages democontracts -PackagePath $packages -OutputDirectory "$OutputRoot\$name" -SmartLink:$SmartLink
    if ($RunExamples) {
        $app = Get-NexusPackageBundle "$OutputRoot\$name"
        $log = Join-Path $app 'result.log'
        $process = Start-Process -FilePath "$app\$name.exe" -ArgumentList ('"'+$log+'"') `
            -WorkingDirectory $OutputRoot -WindowStyle Hidden -PassThru
        if (-not $process.WaitForExit(30000)) { $process.Kill(); throw "$name timed out." }
        $process.Refresh()
        if ($process.ExitCode -ne 0) { throw "$name failed ($($process.ExitCode)). See $log" }
        $expected = @(('PASS late '+$kind.ToLowerInvariant()),'CBLRlrbBLlb')
        if (-not (Test-Path -LiteralPath $log) -or
            ((Get-Content -LiteralPath $log) -join "`n") -cne ($expected -join "`n")) {
            throw "$name did not produce the expected lifecycle result. See $log"
        }
        Write-Host "PASS $name late load, unload, resources, registries and reload"
    }
}
