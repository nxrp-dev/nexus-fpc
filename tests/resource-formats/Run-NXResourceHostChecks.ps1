[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Compiler,
    [Parameter(Mandatory = $true)][string]$RtlUnits,
    [Parameter(Mandatory = $true)][string]$ArtifactRoot,
    [string]$Clang = 'clang',
    [string]$LLVMRC = 'llvm-rc',
    [string]$LLVMCvtRes = 'llvm-cvtres',
    [string]$SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$ResourceSource,
    [string]$Fixtures,
    [string]$MetadataFixtures,
    [switch]$NexusCompiler
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
if (-not $ResourceSource) {
    $ResourceSource = Join-Path $SourceRoot '../nexus/packages/nexus-packages/fcl-res/src'
    if (-not (Test-Path -LiteralPath $ResourceSource)) {
        $ResourceSource = Join-Path $SourceRoot '../../nexus/packages/nexus-packages/fcl-res/src'
    }
}
$ResourceSource = (Resolve-Path -LiteralPath $ResourceSource).Path
$RtlUnits = (Resolve-Path -LiteralPath $RtlUnits).Path
$Compiler = (Get-Command $Compiler -ErrorAction Stop).Source
$Clang = (Get-Command $Clang -ErrorAction Stop).Source
$LLVMRC = (Get-Command $LLVMRC -ErrorAction Stop).Source
$LLVMCvtRes = (Get-Command $LLVMCvtRes -ErrorAction Stop).Source
if (-not $Fixtures) { $Fixtures = Join-Path $SourceRoot 'tests/resource-formats/fixtures/catalog' }
$Fixtures = (Resolve-Path -LiteralPath $Fixtures).Path
if (-not $MetadataFixtures) { $MetadataFixtures = Join-Path $SourceRoot 'tests/resource-formats/fixtures/metadata' }
$MetadataFixtures = (Resolve-Path -LiteralPath $MetadataFixtures).Path
$versionCases = Get-Content -Raw -LiteralPath (Join-Path $MetadataFixtures 'versions.json') |
    ConvertFrom-Json
$ArtifactRoot = [IO.Path]::GetFullPath($ArtifactRoot)
if ($ArtifactRoot.StartsWith($SourceRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase) -or $ArtifactRoot -eq $SourceRoot) {
    throw 'Use an external artifact directory, outside the source/bundle tree.'
}
New-Item -ItemType Directory -Force -Path $ArtifactRoot | Out-Null
$logs = Join-Path $ArtifactRoot 'logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$steps = [Collections.Generic.List[object]]::new()
$suffix = ''
if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { $suffix = '.exe' }

function Invoke-Checked {
    param([string]$Name, [string]$Executable, [string[]]$Arguments)
    $log = Join-Path $logs ($Name + '.log')
    $previousPreference = $ErrorActionPreference
    try {
        # Expected negative LLVM cases print stderr while their Pascal harness
        # exits successfully. Judge the actual process exit code explicitly.
        $ErrorActionPreference = 'Continue'
        & $Executable @Arguments > $log 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    $steps.Add([ordered]@{ Name = $Name; Executable = $Executable;
        Arguments = $Arguments; ExitCode = $code; Log = $log })
    $steps | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 `
        (Join-Path $ArtifactRoot 'commands.json')
    if ($code -ne 0) {
        Get-Content -LiteralPath $log | Write-Host
        throw "$Name failed with exit code $code. Keep the log for analysis."
    }
    Write-Host "PASS $Name"
}

function Compile-Check {
    param([string]$Name)
    $directory = Join-Path $ArtifactRoot $Name
    $units = Join-Path $directory 'units'
    New-Item -ItemType Directory -Force -Path $units | Out-Null
    $executable = Join-Path $directory ($Name + $suffix)
    $arguments = @('-n', '-O2', '-Cr', '-Co', '-Ci')
    if ($NexusCompiler) { $arguments += @('-Aas-clang', '-XLL') }
    $arguments += @("-Fu$RtlUnits", "-Fu$(Join-Path $SourceRoot 'compiler')",
        "-Fu$ResourceSource", "-FU$units",
        "-o$executable", (Join-Path $SourceRoot "tests/resource-formats/$Name.pas"))
    Invoke-Checked "compile-$Name" $Compiler $arguments
    return $executable
}

Invoke-Checked 'compiler-version' $Compiler @('-iV')
Invoke-Checked 'clang-version' $Clang @('--version')
Invoke-Checked 'llvm-rc-version' $LLVMRC @('/?')
[ordered]@{
    Compiler = $Compiler
    CompilerSHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Compiler).Hash
    RtlUnits = $RtlUnits
    OS = [Environment]::OSVersion.VersionString
    HostArchitecture = [Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE')
    NexusCompiler = [bool]$NexusCompiler
} | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $ArtifactRoot 'host.json')

$catalog = Join-Path $ArtifactRoot 'catalog'
New-Item -ItemType Directory -Force -Path $catalog | Out-Null
Copy-Item -Path (Join-Path $Fixtures '*') -Destination $catalog
foreach ($name in @('first', 'second', 'first-images', 'second-images')) {
    Invoke-Checked "rc-$name" $LLVMRC @('/no-preprocess', '/C', '65001', '/I',
        $catalog, '/FO', (Join-Path $catalog "$name.res"), (Join-Path $catalog "$name.rc"))
}
$exe = Compile-Check 'nxResourceCatalogTests'
Invoke-Checked 'catalog' $exe @((Join-Path $catalog 'first.res'),
    (Join-Path $catalog 'second.res'), (Join-Path $catalog 'merged.res'),
    (Join-Path $SourceRoot 'tests/test/units/system/tres4.res'),
    (Join-Path $catalog 'first-images.res'), (Join-Path $catalog 'second-images.res'))
foreach ($machine in @('X86', 'X64', 'ARM64')) {
    foreach ($file in @('merged', 'merged.images')) {
        Invoke-Checked "coff-$machine-$file" $LLVMCvtRes @("/MACHINE:$machine",
            '/TIMESTAMP:0', "/OUT:$(Join-Path $catalog "$file-$machine.obj")",
            (Join-Path $catalog "$file.res"))
    }
}
$exe = Compile-Check 'nxResourceInputsTests'
Invoke-Checked 'inputs' $exe @($SourceRoot, (Join-Path $ArtifactRoot 'nxResourceInputsTests'))
$exe = Compile-Check 'nxResourceToolsTests'
Invoke-Checked 'tools' $exe @($Clang, $LLVMRC, (Join-Path $ArtifactRoot 'nxResourceToolsTests'))
$exe = Compile-Check 'nxResourceArtifactsTests'
Invoke-Checked 'artifacts' $exe @($SourceRoot,
    (Join-Path $ArtifactRoot 'nxResourceArtifactsTests'), $Clang, $LLVMRC)
$exe = Compile-Check 'nxResourceMetadataTests'
Invoke-Checked 'metadata' $exe @((Join-Path $ArtifactRoot 'nxResourceMetadataTests/metadata.bin'))
$exe = Compile-Check 'nxFileInfoMetadataTests'
foreach ($case in $versionCases) {
    Invoke-Checked "fileinfo-$($case.Name)" $exe @(
        (Join-Path $MetadataFixtures $case.First),
        (Join-Path $MetadataFixtures $case.Second))
}
Write-Host "Host checks passed. Return host.json, commands.json and logs from $ArtifactRoot."
