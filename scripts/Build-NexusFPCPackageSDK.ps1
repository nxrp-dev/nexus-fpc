<#
.SYNOPSIS
Build the Win64 runtime-package SDK with Forge after a completed Bootstrap.
.EXAMPLE
.\scripts\Build-NexusFPCPackageSDK.ps1 -OutputRoot output\nxpkg-sdk -RunExamples
#>
[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$Forge,
    [string]$OutputRoot,
    [switch]$BuildExamples,
    [switch]$RunExamples,
    # Consumer compilation option; the SDK foundation has one standard build.
    [switch]$SmartLink
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'NexusFPCPackageArtifacts.ps1')
if (-not $SourceRoot) { $SourceRoot = Join-Path $PSScriptRoot '..' }
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
if (-not $Forge) { $Forge = Join-Path $SourceRoot '../../nexus/output/NexusForge-next/x86_64-win64/nxforge.exe' }
$Forge = (Resolve-Path -LiteralPath $Forge).Path
$bootstrap = Join-Path $SourceRoot 'build/forge-bootstrap'
$sdk = [IO.Path]::GetFullPath((Join-Path $bootstrap 'package-sdk'))
if (-not (Test-Path -LiteralPath (Join-Path $bootstrap 'cycle3/ppcx64.exe'))) {
    throw 'Run NexusFPC.Forge.nxscript /targets=Build:Bootstrap before building the package SDK.'
}
if (-not $OutputRoot) { $OutputRoot = $sdk }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot).TrimEnd('\','/')
if ($OutputRoot -ine $sdk) {
    if ($OutputRoot.StartsWith($sdk+'\',[StringComparison]::OrdinalIgnoreCase) -or
        $sdk.StartsWith($OutputRoot+'\',[StringComparison]::OrdinalIgnoreCase)) {
        throw 'OutputRoot must not overlap the Forge SDK build directory.'
    }
    if ((Test-Path -LiteralPath $OutputRoot) -and (Get-ChildItem -LiteralPath $OutputRoot -Force)) {
        throw 'OutputRoot must be new or empty.'
    }
}
$log = Join-Path $bootstrap 'package-sdk-forge.log'
Push-Location -LiteralPath $SourceRoot
try {
    $ErrorActionPreference = 'Continue'
    & $Forge /input=NexusFPC.Forge.nxscript /targets=Build:PackageSDK *> $log
    $code = $LASTEXITCODE
} finally { Pop-Location; $ErrorActionPreference = 'Stop' }
if ($code -ne 0) { throw "Forge package SDK build failed ($code). Details: $log" }
if ($OutputRoot -ine $sdk) {
    New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
    foreach ($name in @('bin','packages','units','forge','sdk.json')) {
        Copy-Item -LiteralPath (Join-Path $sdk $name) -Destination $OutputRoot -Recurse
    }
}
$bin = Join-Path $OutputRoot 'bin'
Write-Host "Package SDK ready: $OutputRoot. Build log: $log"

if ($BuildExamples -or $RunExamples) {
    $exampleSource = Join-Path $SourceRoot 'examples\dynamic-packages'
    $examplePackages = Join-Path $OutputRoot 'examples\packages'
    New-Item -ItemType Directory -Force -Path $examplePackages | Out-Null
    $helper = Join-Path $PSScriptRoot 'Invoke-NexusFPCPackageCompile.ps1'
    foreach ($name in @('demotypes','demoleft','demoright')) {
        & $helper -Forge $Forge -SdkRoot $OutputRoot -Source "$exampleSource\$name\$name.ppk" -Kind Package `
            -PackagePath $examplePackages -OutputDirectory $examplePackages -SmartLink:$SmartLink
    }
    foreach ($kind in @('Console','GUI')) {
        $name = 'demo_' + $kind.ToLowerInvariant()
        & $helper -Forge $Forge -SdkRoot $OutputRoot -Source "$exampleSource\host\$name.pas" -Kind $kind `
            -RequiredPackages demotypes,demoleft,demoright -PackagePath $examplePackages `
            -OutputDirectory "$OutputRoot\examples\$name" -SmartLink:$SmartLink
        if ($RunExamples) {
            $directory = Get-NexusPackageBundle (Join-Path $OutputRoot "examples\$name")
            $result = Join-Path $directory 'result.log'
            $process = Start-Process -FilePath "$directory\$name.exe" -ArgumentList ('"'+$result+'"') `
                -WorkingDirectory $directory -WindowStyle Hidden -PassThru
            if (-not $process.WaitForExit(30000)) {
                $process.Kill()
                throw "$name did not exit within 30 seconds."
            }
            $process.Refresh()
            if ($process.ExitCode -ne 0) { throw "$name failed ($($process.ExitCode)). See $result" }
            $expected = @('init=BLRH',('PASS ' + $kind.ToLowerInvariant()),'final=h','final=r','final=l','final=b')
            if (-not (Test-Path -LiteralPath $result) -or
                ((Get-Content -LiteralPath $result) -join "`n") -cne ($expected -join "`n")) {
                throw "$name did not produce the expected lifecycle result. See $result"
            }
            Write-Host "PASS $name identity, managed ownership, initialization and finalization"
        }
    }
}
