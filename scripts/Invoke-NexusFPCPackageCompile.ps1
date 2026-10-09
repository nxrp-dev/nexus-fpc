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
$SdkRoot = (Resolve-Path -LiteralPath $SdkRoot).Path
$Source = (Resolve-Path -LiteralPath $Source).Path
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$compiler = Join-Path $SdkRoot 'bin\ppcpkg.exe'
$sdkUnits = Join-Path $SdkRoot 'units'
foreach ($inputPath in @($compiler, "$SdkRoot\sdk.json", "$sdkUnits\sysinitpkg.ppu")) {
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) { throw "Missing SDK input: $inputPath" }
}
if (-not (Get-Command clang.exe -ErrorAction SilentlyContinue) -or
    -not (Get-Command lld-link.exe -ErrorAction SilentlyContinue)) { throw 'LLVM Clang and LLD must be on PATH.' }
$packageDirectories = @((Join-Path $SdkRoot 'packages'))
foreach ($directory in $PackagePath) { $packageDirectories += (Resolve-Path -LiteralPath $directory).Path }
$unitDirectories = @((Split-Path -Parent $Source))
foreach ($directory in $UnitPath) { $unitDirectories += (Resolve-Path -LiteralPath $directory).Path }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$work = Join-Path $OutputDirectory ('work-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$name = [IO.Path]::GetFileNameWithoutExtension($Source)
$arguments = @('-n','-Mobjfpc',"-Fu$sdkUnits","-FU$work","-FE$work")
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
if ($Kind -eq 'Package') {
    foreach ($extension in @('.pcp','.dll')) {
        if (-not (Test-Path -LiteralPath "$work\$name$extension")) {
            throw "Expected $name$extension was not produced. Package name must match its source filename. See $log"
        }
    }
    foreach ($extension in @('.pcp','.dll')) { Copy-Item -LiteralPath "$work\$name$extension" -Destination $OutputDirectory }
} else {
    $dlls = @{}
    foreach ($directory in $packageDirectories) {
        foreach ($dll in Get-ChildItem -LiteralPath $directory -Filter '*.dll' -File) {
            if ($dlls.ContainsKey($dll.Name) -and
                (Get-FileHash -LiteralPath $dll.FullName).Hash -ne (Get-FileHash -LiteralPath $dlls[$dll.Name]).Hash) {
                throw "Conflicting package DLLs named $($dll.Name) in the supplied package directories."
            }
            $dlls[$dll.Name] = $dll.FullName
        }
    }
    foreach ($dll in $dlls.Values) { Copy-Item -LiteralPath $dll -Destination $OutputDirectory }
    Copy-Item -LiteralPath "$work\$name.exe" -Destination $OutputDirectory
}
Write-Host "Built $Kind $name. Output: $OutputDirectory. Log: $log"
