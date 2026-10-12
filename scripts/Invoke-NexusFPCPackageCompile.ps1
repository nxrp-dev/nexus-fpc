<#
.SYNOPSIS
Invoke the native Forge package build from existing PowerShell example/test callers.
.DESCRIPTION
This transitional adapter supplies a Forge document and captures its output.
SDK checks, compiler execution, dependency checks and publication belong to Forge.
New consumers should compose the SDK's forge/PackageBuild.nxscript directly.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SdkRoot,
    [Parameter(Mandatory=$true)][string]$Source,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [Parameter(Mandatory=$true)][ValidateSet('Package','Console','GUI')][string]$Kind,
    [string[]]$RequiredPackages = @(),
    [string[]]$PackagePath = @(),
    [string[]]$UnitPath = @(),
    [switch]$SmartLink,
    [string]$Forge
)
$ErrorActionPreference = 'Stop'
$nexusRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../nexus'))
if (-not $Forge) { $Forge = Join-Path $nexusRoot 'output/NexusForge-next/x86_64-win64/nxforge.exe' }
$Forge = (Resolve-Path -LiteralPath $Forge).Path
function ScriptPath([string]$Path) { '"'+[IO.Path]::GetFullPath($Path).Replace('\','/')+'"' }
$sdk = ScriptPath $SdkRoot
$sourcePath = ScriptPath $Source
$output = ScriptPath $OutputDirectory
$dialect = ScriptPath (Join-Path $nexusRoot 'projects/forge/language/Forge.nxscript')
$recipe = ScriptPath (Join-Path $SdkRoot 'forge/PackageBuild.nxscript')
$name = [IO.Path]::GetFileNameWithoutExtension($Source)
if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_.-]*$') { throw 'Invalid package/application filename.' }
foreach ($package in $RequiredPackages) {
    if ($package -notmatch '^[A-Za-z_][A-Za-z0-9_.]*$') { throw "Invalid package name: $package" }
}
$paths = (@($PackagePath | ForEach-Object { ScriptPath $_ })) -join ', '
$units = (@($UnitPath | ForEach-Object { ScriptPath $_ })) -join ', '
$required = (@('nxrtl') + $RequiredPackages | Select-Object -Unique | ForEach-Object { '"'+$_+'"' }) -join ', '
$application = ''
if ($Kind -eq 'Console') { $application = "RequiredPackages: [$required]; ConsoleApplication: True;" }
if ($Kind -eq 'GUI') { $application = "RequiredPackages: [$required]; GUIApplication: True;" }
$smart = if ($SmartLink) { 'True' } else { 'False' }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$work = ScriptPath (Join-Path $OutputDirectory ('work-'+[guid]::NewGuid().ToString('N')))
$document = @"
dialect $dialect;
module PackageBuild $recipe;
Project Build {
    Id: "NXRP.PackageBuild.$name";
    Group Steps (PackageBuild) {
        PackageBuildPrepare Prepare (PackageBuild.Prepare) { SDKDirectory: $sdk; WorkDirectory: $work; PackageDirectories: [$paths]; }
        FPC Compile (PackageBuild.Compile) { EntryPoint: $sourcePath; UnitPaths: [$units]; SmartLinkUnits: $smart; SmartLink: $smart; $application }
        PackageBundlePublish Publish (PackageBuild.Publish) { Name: "$name"; Kind: $Kind; OutputDirectory: $output; }
    }
}
"@
$inputFile = Join-Path $OutputDirectory "build-$name.nxscript"
[IO.File]::WriteAllText($inputFile,$document,[Text.UTF8Encoding]::new($false))
$log = Join-Path $OutputDirectory "build-$name.log"
try {
    $ErrorActionPreference = 'Continue'
    & $Forge "/input=$inputFile" *> $log
    $code = $LASTEXITCODE
} finally { $ErrorActionPreference = 'Stop' }
if ($code -ne 0) { throw "Forge package build failed. Details: $log`n$([IO.File]::ReadAllText($log))" }
Write-Host "Built $Kind $name with Forge. Log: $log"
