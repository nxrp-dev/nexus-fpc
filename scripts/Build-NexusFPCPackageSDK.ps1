<#
.SYNOPSIS
Build an isolated experimental Win64 package SDK from an FPC 3.2.2 bootstrap.
.EXAMPLE
.\scripts\Build-NexusFPCPackageSDK.ps1 -OutputRoot C:\temp\nxpkg-sdk -BuildExamples
#>
[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$BootstrapBin = 'C:\lazarus\fpc\3.2.2\bin\x86_64-win64',
    [string]$OutputRoot,
    [switch]$BuildExamples,
    [switch]$RunExamples,
    [switch]$SmartLink
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'NexusFPCPackageArtifacts.ps1')
if (-not $SourceRoot) { $SourceRoot = Join-Path $PSScriptRoot '..' }
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$BootstrapBin = (Resolve-Path -LiteralPath $BootstrapBin).Path
if (-not $OutputRoot) {
    $OutputRoot = Join-Path $SourceRoot ('output\NexusFPCPackages\' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
}
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
foreach ($directory in @($SourceRoot,$BootstrapBin,$OutputRoot)) {
    if ($directory -match '\s') { throw "The RTL GNU make build requires paths without whitespace: $directory" }
}
if ((Test-Path -LiteralPath $OutputRoot) -and (Get-ChildItem -LiteralPath $OutputRoot -Force)) {
    throw 'OutputRoot must be new or empty. Each SDK is a matching compiler/RTL build.'
}
$bootstrap = Join-Path $BootstrapBin 'ppcx64.exe'
$make = Join-Path $BootstrapBin 'make.exe'
$bootstrapRtl = [IO.Path]::GetFullPath((Join-Path $BootstrapBin '..\..\units\x86_64-win64\rtl'))
foreach ($inputPath in @($bootstrap,$make,"$SourceRoot\compiler\ppcpkg.pas","$bootstrapRtl\system.ppu")) {
    if (-not (Test-Path -LiteralPath $inputPath)) { throw "Missing build input: $inputPath" }
}
if ((& $bootstrap -iV) -ne '3.2.2' -or (& $bootstrap -iTP) -ne 'x86_64' -or (& $bootstrap -iTO) -ne 'win64') {
    throw 'Requires an FPC 3.2.2 Win64 bootstrap.'
}
foreach ($tool in @('clang.exe','lld-link.exe')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "$tool must be on PATH." }
}
$work = Join-Path $OutputRoot 'work'
$bin = Join-Path $OutputRoot 'bin'
$packages = Join-Path $OutputRoot 'packages'
$units = Join-Path $OutputRoot 'units'
$logs = Join-Path $OutputRoot 'logs'
$compilerSource = Join-Path $work 'compiler-source'
$compilerUnits = Join-Path $work 'compiler-units'
$rtl = Join-Path $work 'rtl-units'
$rtlBin = Join-Path $work 'rtl-bin'
$foundation = Join-Path $work 'nxrtl'
foreach ($directory in @($bin,$packages,$units,$logs,$compilerSource,$compilerUnits,$rtl,$rtlBin,$foundation)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}
$steps = [Collections.Generic.List[object]]::new()
function Invoke-PackageStep([string]$Name,[string]$Executable,[string[]]$StepArgs,[string]$Directory=$work) {
    $log = Join-Path $logs ($Name + '.log')
    Push-Location -LiteralPath $Directory
    try {
        $ErrorActionPreference = 'Continue'
        & $Executable @StepArgs *> $log
        $code = $LASTEXITCODE
    } finally { Pop-Location; $ErrorActionPreference = 'Stop' }
    $steps.Add([pscustomobject]@{Name=$Name;Command=@($Executable)+$StepArgs;ExitCode=$code;Log=$log})
    $steps.ToArray() | ConvertTo-Json -Depth 5 | Set-Content "$logs\steps.json" -Encoding UTF8
    if ($code -ne 0) { throw "$Name failed ($code). Details: $log" }
    Write-Host "PASS $Name"
}

# Stage source files only. Compiler PPUs and generated message includes from an
# earlier ordinary bootstrap cannot leak into this compiler build.
$originalCompiler = Join-Path $SourceRoot 'compiler'
foreach ($file in Get-ChildItem -LiteralPath $originalCompiler -Recurse -File) {
    if ($file.Extension -notin @('.pas','.pp','.inc') -or $file.Name -in @('msgtxt.inc','msgidx.inc')) { continue }
    $destination = Join-Path $compilerSource $file.FullName.Substring($originalCompiler.Length+1)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination
}
$bootstrapOptions = @('-n',"-Fu$bootstrapRtl","-FU$compilerUnits")
Invoke-PackageStep 'message-generator' $bootstrap ($bootstrapOptions + @("-FE$work","$compilerSource\utils\msg2inc.pp"))
Invoke-PackageStep 'messages' "$work\msg2inc.exe" @("$SourceRoot\compiler\msg\errore.msg","$compilerSource\msg",'msg')
$compilerOptions = $bootstrapOptions + @('-O2','-dx86_64',"-Fu$compilerUnits","-FE$bin")
foreach ($part in @('','x86_64','x86','systems')) {
    $directory = Join-Path $compilerSource $part
    $compilerOptions += @("-Fu$directory","-Fi$directory")
}
Invoke-PackageStep 'package-compiler' $bootstrap ($compilerOptions + @("$compilerSource\ppcpkg.pas"))
$compiler = Join-Path $bin 'ppcpkg.exe'
$oldPath = $env:PATH
try {
    $env:PATH = "$BootstrapBin;$oldPath"
    Invoke-PackageStep 'matching-rtl' $make @('-s','-C',"$SourceRoot\rtl\win64",'all',
        "FPC=$($compiler.Replace('\','/'))",'CPU_TARGET=x86_64','OS_TARGET=win64',
        "COMPILER_UNITTARGETDIR=$($rtl.Replace('\','/'))","COMPILER_TARGETDIR=$($rtlBin.Replace('\','/'))",
        "FPCMADE=$($work.Replace('\','/'))/rtl.fpcmade",'OPT=-n')
} finally { $env:PATH = $oldPath }
# One conservative SDK identity binds this compiler and its complete RTL sources.
$identityParts = @((Get-FileHash -LiteralPath $compiler).Hash,('SmartLink='+[bool]$SmartLink))
foreach ($file in Get-ChildItem -LiteralPath "$SourceRoot\rtl" -Recurse -File | Sort-Object FullName) {
    if ($file.Extension -in @('.pp','.pas','.inc')) {
        $identityParts += $file.FullName.Substring($SourceRoot.Length) + ':' + (Get-FileHash -LiteralPath $file.FullName).Hash
    }
}
$hash = [Security.Cryptography.SHA256]::Create()
try { $sdkIdentity = [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes(($identityParts -join "`n")))).Replace('-','') }
finally { $hash.Dispose() }
$packageOptions = @('-n','-Mobjfpc',"-Fj$sdkIdentity",('-Fk'+[guid]::NewGuid().ToString('N')), "-Fu$rtl")
if ($SmartLink) { $packageOptions += @('-CX','-XX') }
# Compile the declaration away from rtl/win64: a source beside the input file
# takes precedence over a cached System PPU in a later unit search directory.
Copy-Item -LiteralPath "$SourceRoot\rtl\win64\nxrtl.ppk" -Destination $foundation
Invoke-PackageStep 'shared-rtl' $compiler ($packageOptions + @("-Fu$SourceRoot\rtl\inc",
    "-FU$foundation","-FE$foundation","$foundation\nxrtl.ppk"))
Copy-Item -LiteralPath "$foundation\nxrtl.pcp","$foundation\nxrtl.dll" -Destination $packages
# These are per-image adapters. All provider unit metadata comes from nxrtl.pcp.
Copy-Item -LiteralPath "$rtl\fpintres.ppu","$rtl\fpintres.o","$rtl\libimpfpintres.a" -Destination $units
Copy-Item -LiteralPath "$SourceRoot\rtl\win64\sysinitpkg.pp" -Destination $work
Invoke-PackageStep 'host-startup' $compiler @('-n','-Mobjfpc',"-Fu$units","-Fp$packages","-Fl$packages",
    '-FPnxrtl',"-Fj$sdkIdentity","-FU$units","$work\sysinitpkg.pp")
Copy-Item -LiteralPath "$SourceRoot\scripts\Invoke-NexusFPCPackageCompile.ps1","$SourceRoot\scripts\NexusFPCPackageArtifacts.ps1" -Destination $bin
$artifacts = @()
foreach ($file in @((Get-Item -LiteralPath $compiler)) + @(Get-ChildItem -LiteralPath $units,$packages -File)) {
    $artifacts += [pscustomobject]@{Path=$file.FullName.Substring($OutputRoot.Length+1);SHA256=(Get-FileHash -LiteralPath $file.FullName).Hash}
}
[pscustomobject]@{Format=2;Target='x86_64-win64';Experimental=$true;Foundation='nxrtl';
    CompilerVersion=(& $compiler -iV);SmartLink=[bool]$SmartLink;SDKIdentity=$sdkIdentity;Artifacts=$artifacts} |
    ConvertTo-Json -Depth 5 | Set-Content "$OutputRoot\sdk.json" -Encoding UTF8
Write-Host "Package SDK ready: $OutputRoot"

if ($BuildExamples -or $RunExamples) {
    $exampleSource = Join-Path $SourceRoot 'examples\dynamic-packages'
    $examplePackages = Join-Path $OutputRoot 'examples\packages'
    New-Item -ItemType Directory -Force -Path $examplePackages | Out-Null
    $helper = Join-Path $bin 'Invoke-NexusFPCPackageCompile.ps1'
    foreach ($name in @('demotypes','demoleft','demoright')) {
        & $helper -SdkRoot $OutputRoot -Source "$exampleSource\$name\$name.ppk" -Kind Package `
            -PackagePath $examplePackages -OutputDirectory $examplePackages -SmartLink:$SmartLink
    }
    foreach ($kind in @('Console','GUI')) {
        $name = 'demo_' + $kind.ToLowerInvariant()
        & $helper -SdkRoot $OutputRoot -Source "$exampleSource\host\$name.pas" -Kind $kind `
            -RequiredPackages demotypes,demoleft,demoright -PackagePath $examplePackages `
            -OutputDirectory "$OutputRoot\examples\$name" -SmartLink:$SmartLink
        if ($RunExamples) {
            $directory = Get-NexusPackageBundle (Join-Path $OutputRoot "examples\$name")
            $result = Join-Path $directory 'result.log'
            $process = Start-Process -FilePath "$directory\$name.exe" -ArgumentList $result `
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
