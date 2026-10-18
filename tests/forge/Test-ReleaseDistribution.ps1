# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
[CmdletBinding()]
param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot '../..'),
    [switch]$InputsOnly,
    [string]$ReleaseRoot,
    [string]$OutputRoot
)
$ErrorActionPreference = 'Stop'
$targets = @(
    'i386-linux', 'x86_64-linux', 'aarch64-linux',
    'i386-win32', 'x86_64-win64', 'aarch64-win64',
    'x86_64-android', 'aarch64-android', 'x86_64-darwin', 'aarch64-darwin',
    'x86_64-iphonesim', 'aarch64-iphonesim', 'aarch64-ios'
)
$compilers = @{i386='ppcross386.exe'; x86_64='ppcrossx64.exe'; aarch64='ppcrossa64.exe'}
$tools = @('fpc','ppufiles','mkx86ins','mkx86reg','mkx86inl','mka64ins','mka64reg','msg2inc',
    'rstconv','bin2obj')

function Require-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing release input: $Path" }
}
function Assert-Same([string]$Left, [string]$Right) {
    Require-File $Left
    Require-File $Right
    if ((Get-FileHash -LiteralPath $Left).Hash -ne (Get-FileHash -LiteralPath $Right).Hash) {
        throw "Release file mismatch: $Left; $Right"
    }
}
function Run-Step([string]$Name, [string]$Executable, [string[]]$Arguments, [switch]$ExpectFailure) {
    $log = Join-Path $OutputRoot ($Name+'.log')
    $ErrorActionPreference = 'Continue'
    & $Executable @Arguments *> $log
    $code = $LASTEXITCODE
    $steps.Add([pscustomobject]@{Step=$Name; ExitCode=$code; ExpectedFailure=[bool]$ExpectFailure; Log=$log})
    $steps.ToArray() | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputRoot 'steps.json')
    if (($ExpectFailure -and $code -eq 0) -or (-not $ExpectFailure -and $code -ne 0)) {
        Get-Content -LiteralPath $log -Tail 18 | Write-Host
        throw "$Name returned unexpected exit code $code"
    }
    Write-Host "PASS $Name"
}
function Assert-RelocatedUnits([string]$LogName, [string]$Target) {
    $text = Get-Content -LiteralPath (Join-Path $OutputRoot ($LogName+'.log')) -Raw
    $paths = [regex]::Matches($text, '(?im)PPU Name:\s*(.+\.nxu)\s*$')
    if ($paths.Count -eq 0) { throw "No loaded-unit evidence in $LogName" }
    $expected = [IO.Path]::GetFullPath((Join-Path $relocated "units/$Target/rtl")) + '\'
    foreach ($match in $paths) {
        $path = $match.Groups[1].Value.Trim()
        if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $OutputRoot $path }
        $path = [IO.Path]::GetFullPath($path)
        if (-not $path.StartsWith($expected, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Unit loaded outside the relocated target RTL: $path"
        }
    }
}

try {
    $SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
    $bootstrap = Join-Path $SourceRoot 'build/forge-bootstrap'
    $toolBin = Join-Path $bootstrap 'tools/bin'
    $identityFile = Join-Path $bootstrap 'seed/build-identity.json'
    if ($InputsOnly) {
        Require-File $identityFile
        foreach ($name in $tools) { Require-File (Join-Path $toolBin ($name+'.exe')) }
        $native = Join-Path $bootstrap 'cycle3/ppcx64.exe'
        Assert-Same $native (Join-Path $toolBin 'ppcx64.exe')
        $canonical = @{x86_64=$native}
        foreach ($target in $targets) {
            $cpu = $target.Split('-')[0]
            $directory = Join-Path $bootstrap ('cross/'+$target)
            $compiler = Join-Path $directory $compilers[$cpu]
            Require-File $compiler
            foreach ($unit in @('system','sysutils','classes')) {
                Require-File (Join-Path $directory ('rtl/'+$unit+'.nxu'))
                Require-File (Join-Path $directory ('rtl/'+$unit+'.o'))
            }
            if ($canonical.ContainsKey($cpu)) { Assert-Same $canonical[$cpu] $compiler }
            else { $canonical[$cpu] = $compiler }
        }
        foreach ($compiler in $canonical.Values) {
            & (Join-Path $SourceRoot 'tests/forge/Test-NexusFPCBuildIdentity.ps1') -Compiler $compiler -IdentityFile $identityFile
        }
        Write-Host "PASS release inputs: $($tools.Count) tools, three matching compiler families, 13 target RTLs"
        exit 0
    }

    if (-not $ReleaseRoot) { $ReleaseRoot = Join-Path $bootstrap 'distribution' }
    $ReleaseRoot = (Resolve-Path -LiteralPath $ReleaseRoot).Path
    if (-not $OutputRoot) { $OutputRoot = Join-Path $bootstrap 'release-checks' }
    $OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
    if (Test-Path -LiteralPath $OutputRoot) { throw 'Use a new output directory for release-distribution checks.' }
    New-Item -ItemType Directory -Path $OutputRoot | Out-Null
    $steps = [Collections.Generic.List[object]]::new()
    $bin = Join-Path $ReleaseRoot 'bin/x86_64-win64'
    foreach ($name in ($tools | ForEach-Object { $_+'.exe' }) + @('ppcx64.exe')) {
        Assert-Same (Join-Path $toolBin $name) (Join-Path $bin $name)
    }
    foreach ($cpu in @('i386','aarch64')) {
        Assert-Same (Join-Path $bootstrap ('cross/'+$cpu+'-linux/'+$compilers[$cpu])) (Join-Path $bin $compilers[$cpu])
    }
    Assert-Same $identityFile (Join-Path $ReleaseRoot 'build-identity.json')
    $unitFiles = 0
    foreach ($target in $targets) {
        $source = Join-Path $bootstrap ('cross/'+$target+'/rtl')
        $destination = Join-Path $ReleaseRoot ('units/'+$target+'/rtl')
        $files = @(Get-ChildItem -LiteralPath $source -File | Where-Object {
            $_.Extension -in @('.nxu','.o','.a','.res','.rsj') -and $_.BaseName -ne 'buildrtl'
        })
        if (@(Get-ChildItem -LiteralPath $destination -File).Count -ne $files.Count) {
            throw "Unexpected release unit contents: $target"
        }
        foreach ($file in $files) { Assert-Same $file.FullName (Join-Path $destination $file.Name) }
        $unitFiles += $files.Count
    }
    $config = Get-Content -LiteralPath (Join-Path $bin 'fpc.cfg') -Raw
    if (-not $config.Contains('-Fu$FPCBINDIR/../../units/$FPCTARGET/rtl')) { throw 'Release config must use compiler-relative unit paths.' }
    if ($config -match '(?i)[a-z]:[/\\]|forge-bootstrap|%basepath%') { throw 'Release config contains an unresolved or machine-specific path.' }

    # A space in the new location catches path quoting errors. No source/PPU search overrides.
    $relocated = Join-Path $OutputRoot 'relocated distribution'
    Copy-Item -LiteralPath $ReleaseRoot -Destination $relocated -Recurse
    $bin = Join-Path $relocated 'bin/x86_64-win64'
    $driver = Join-Path $bin 'fpc.exe'
    $clang = (Get-Command clang.exe -CommandType Application -ErrorAction Stop).Source
    $llvmrc = (Get-Command llvm-rc.exe -CommandType Application -ErrorAction Stop).Source
    $linker = (Get-Command ld.lld.exe -CommandType Application -ErrorAction Stop).Source
    $savedEnvironment = @{}
    foreach ($name in @('PATH','FPCDIR','WIN32UNITS','WIN64UNITS','LINUXUNITS','ANDROIDUNITS','BSDUNITS',
        'PPC_CONFIG_PATH','PPC_EXEC_PATH','USERPROFILE','ALLUSERSPROFILE')) {
        $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable($name, $null, 'Process')
    }
    $env:PATH = ((@((Split-Path $clang), (Split-Path $llvmrc), (Split-Path $linker), (Join-Path $env:SystemRoot 'System32')) | Select-Object -Unique) -join ';')
    Push-Location $OutputRoot
    try {
        [IO.File]::WriteAllText((Join-Path $OutputRoot 'smoke.rc'), '101 RCDATA { 42 }')
        [IO.File]::WriteAllText((Join-Path $OutputRoot 'releaseprobe.pas'), @'
unit releaseprobe;
{$mode objfpc}{$H+}
interface
uses SysUtils, Classes, Dynlibs;
function Probe: string;
implementation
{$R smoke.rc}
function Probe: string;
var items: TStringList; lStream: TResourceStream; lValue: Word;
begin
  lStream := TResourceStream.CreateFromID(HInstance, 101, PChar(10));
  try lStream.ReadBuffer(lValue, SizeOf(lValue)); finally lStream.Free; end;
  if lValue <> 42 then Halt(1);
  items := TStringList.Create;
  try
    items.Add(IntToStr(SizeOf(Pointer)));
    Result := items[0];
  finally
    items.Free;
  end;
end;
end.
'@)
        foreach ($target in $targets) {
            $cpu, $os = $target.Split('-')
            $targetOutput = Join-Path $OutputRoot $target
            New-Item -ItemType Directory -Path $targetOutput | Out-Null
            Run-Step ('compile-'+$target) $driver @(('-P'+$cpu), ('-T'+$os), '-vu', ('-FU'+$targetOutput), 'releaseprobe.pas')
            Require-File (Join-Path $targetOutput 'releaseprobe.o')
            Assert-RelocatedUnits ('compile-'+$target) $target
        }
        [IO.File]::WriteAllText((Join-Path $OutputRoot 'smoke.pas'), @'
program smoke;
{$mode objfpc}{$H+}
{$R smoke.rc}
uses SysUtils, Classes;
var items: TStringList; lStream: TResourceStream; lValue: Word;
begin
  lStream := TResourceStream.CreateFromID(HInstance, 101, PChar(10));
  try lStream.ReadBuffer(lValue, SizeOf(lValue)); finally lStream.Free; end;
  if lValue <> 42 then Halt(1);
  items := TStringList.Create;
  try
    items.Add('relocated-release-ok');
    WriteLn(items[0]);
  finally
    items.Free;
  end;
end.
'@)
        foreach ($target in @('x86_64-win64','i386-win32','aarch64-win64','i386-linux','x86_64-linux','aarch64-linux')) {
            $cpu, $os = $target.Split('-')
            $targetOutput = Join-Path $OutputRoot $target
            $arguments = @('-vu', ('-FU'+$targetOutput), ('-o'+(Join-Path $targetOutput 'smoke.exe')), 'smoke.pas')
            # Exercise the native default without -P/-T as well as explicit cross selection.
            if ($target -ne 'x86_64-win64') { $arguments = @(('-P'+$cpu), ('-T'+$os)) + $arguments }
            Run-Step ('link-'+$target) $driver $arguments
            Assert-RelocatedUnits ('link-'+$target) $target
            if ($target -in @('x86_64-win64','i386-win32')) {
                Run-Step ('run-'+$target) (Join-Path $targetOutput 'smoke.exe') @()
                if ((Get-Content -LiteralPath (Join-Path $OutputRoot ('run-'+$target+'.log')) -Raw).Trim() -ne 'relocated-release-ok') {
                    throw "Unexpected smoke output: $target"
                }
            }
        }
        # Missing shipped units must fail instead of finding an installed FPC/checkout RTL.
        $systemUnit = Join-Path $relocated 'units/i386-win32/rtl/system.nxu'
        Move-Item -LiteralPath $systemUnit -Destination ($systemUnit+'.held')
        try {
            Run-Step 'missing-rtl-rejected' $driver @('-Pi386','-Twin32',('-FU'+(Join-Path $OutputRoot 'i386-win32')),'releaseprobe.pas') -ExpectFailure
            if ((Get-Content -LiteralPath (Join-Path $OutputRoot 'missing-rtl-rejected.log') -Raw) -notmatch "Can't find unit system") {
                throw 'Missing-RTL check failed for an unrelated reason.'
            }
        } finally {
            Move-Item -LiteralPath ($systemUnit+'.held') -Destination $systemUnit
        }
    } finally {
        Pop-Location
        foreach ($name in $savedEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
        }
    }
    [pscustomobject]@{Targets=$targets.Count; Tools=$tools.Count; Compilers=3; UnitFiles=$unitFiles;
        Steps=$steps.Count; Relocation='passed'; WindowsExecution='x86_64, i386';
        LinkOnly='aarch64-win64, i386-linux, x86_64-linux, aarch64-linux';
        CompileOnly='Android, Darwin, iPhone simulator, iOS'} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputRoot 'results.json')
    Write-Host 'PASS relocated release: all target unit searches, six linked programs, two executed programs'
} catch {
    Write-Host ('FAIL: '+$_.Exception.Message)
    exit 1
}
