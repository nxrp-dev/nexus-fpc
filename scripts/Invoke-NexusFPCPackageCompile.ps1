<#
.SYNOPSIS
Compile an experimental Win64 package, console host, or GUI host using a package SDK.
.DESCRIPTION
Package declarations specify their own requirements. Applications explicitly list
their required packages; nxrtl is always included. Additional package directories
must contain the complete matching PCP/DLL dependency set. No dependency acquisition
or late loading is performed. Native commands and diagnostics are saved in logs.
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
    [switch]$SmartLink
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'NexusFPCPackageArtifacts.ps1')
$SdkRoot = (Resolve-Path -LiteralPath $SdkRoot).Path
$Source = (Resolve-Path -LiteralPath $Source).Path
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$compiler = Join-Path $SdkRoot 'bin\ppcx64.exe'
$sdkUnits = Join-Path $SdkRoot 'units'
foreach ($inputPath in @($compiler, "$SdkRoot\sdk.json", "$sdkUnits\sysinitpkg.ppu")) {
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) { throw "Missing SDK input: $inputPath" }
}
if (-not (Get-Command clang.exe -ErrorAction SilentlyContinue) -or
    -not (Get-Command lld-link.exe -ErrorAction SilentlyContinue)) { throw 'LLVM Clang and LLD must be on PATH.' }
$sdk = Get-Content -LiteralPath "$SdkRoot\sdk.json" -Raw | ConvertFrom-Json
if ($sdk.Format -ne 2 -or $sdk.SDKIdentity -notmatch '^[0-9A-Fa-f]{64}$') { throw 'Requires a version-2 package SDK.' }
foreach ($artifact in $sdk.Artifacts) {
    if ((Get-FileHash -LiteralPath (Join-Path $SdkRoot $artifact.Path)).Hash -ne $artifact.SHA256) {
        throw "SDK artifact differs from its recorded build: $($artifact.Path)"
    }
}
$packageDirectories = @((Get-NexusPackageBundle (Join-Path $SdkRoot 'packages')))
foreach ($directory in $PackagePath) { $packageDirectories += Get-NexusPackageBundle $directory }
$unitDirectories = @((Split-Path -Parent $Source))
foreach ($directory in $UnitPath) { $unitDirectories += (Resolve-Path -LiteralPath $directory).Path }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$work = Join-Path $OutputDirectory ('work-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$name = [IO.Path]::GetFileNameWithoutExtension($Source)
$arguments = @('-n','-Mobjfpc',"-Fj$($sdk.SDKIdentity)",('-Fk'+[guid]::NewGuid().ToString('N')),"-Fu$sdkUnits","-FU$work","-FE$work")
foreach ($directory in $packageDirectories) { $arguments += @("-Fp$directory","-Fl$directory") }
foreach ($directory in $unitDirectories) { $arguments += "-Fu$directory" }
if ($SmartLink) { $arguments += @('-CX','-XX') }
if ($Kind -ne 'Package') {
    foreach ($package in (@('nxrtl') + $RequiredPackages | Select-Object -Unique)) {
        if ($package -notmatch '^[A-Za-z_][A-Za-z0-9_.]*$') { throw "Invalid package name: $package" }
        $arguments += "-FP$package"
    }
    if ($Kind -eq 'GUI') { $arguments += '-WG' } else { $arguments += '-WC' }
}
$arguments += $Source
$log = Join-Path $work 'compile.log'
Push-Location -LiteralPath $work
try {
    $ErrorActionPreference = 'Continue'
    & $compiler @arguments *> $log
    $code = $LASTEXITCODE
} finally { Pop-Location; $ErrorActionPreference = 'Stop' }
[pscustomobject]@{ Source=$Source; Kind=$Kind; Compiler=$compiler; Arguments=$arguments;
    ExitCode=$code; Log=$log } | ConvertTo-Json -Depth 5 | Set-Content "$work\build.json" -Encoding UTF8
if ($code -ne 0) { throw "Compilation failed ($code). Details: $log" }
$published = Publish-NexusPackageBundle -OutputDirectory $OutputDirectory -Work $work -Name $name `
    -Kind $Kind -SDKIdentity $sdk.SDKIdentity -PackageDirectories $packageDirectories
Write-Host "Built $Kind $name. Bundle: $published. Log: $log"
