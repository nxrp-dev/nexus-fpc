# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
[CmdletBinding()]
param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot '../..'),
    [Parameter(Mandatory)][string]$BootstrapDirectory,
    [string]$OutputRoot
)
$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$bootstrap = [IO.Path]::GetFullPath($BootstrapDirectory)
$bin = Join-Path $bootstrap 'tools/bin'
$rtl = Join-Path $bootstrap 'cycle3/rtl64'
if (-not $OutputRoot) { $OutputRoot = Join-Path $bootstrap 'tools/checks' }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $OutputRoot) { throw 'Use a new output directory for release-tool checks.' }
New-Item -ItemType Directory -Path $OutputRoot | Out-Null
$steps = [Collections.Generic.List[object]]::new()
function Run-Step([string]$Name, [string]$Executable, [string[]]$Arguments) {
    $log = Join-Path $OutputRoot ($Name+'.log')
    $ErrorActionPreference = 'Continue'
    & $Executable @Arguments *> $log
    $code = $LASTEXITCODE
    $steps.Add([pscustomobject]@{Step=$Name; ExitCode=$code; Log=$log})
    $steps.ToArray() | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputRoot 'steps.json')
    if ($code -ne 0) { Get-Content -LiteralPath $log -Tail 15 | Write-Host; throw "$Name failed: $code" }
    Write-Host "PASS $Name"
}
function Write-Fixture([string]$Name, [string]$Text) {
    [IO.File]::WriteAllText((Join-Path $OutputRoot $Name), $Text, [Text.UTF8Encoding]::new($false))
}
function Assert-Contains([string]$Name, [string]$Text) {
    if (-not [IO.File]::ReadAllText((Join-Path $OutputRoot $Name)).Contains($Text)) { throw "$Name does not contain $Text" }
}
function Assert-Same([string]$Left, [string]$Right) {
    if ((Get-FileHash -LiteralPath $Left).Hash -ne (Get-FileHash -LiteralPath $Right).Hash) { throw "Generated file mismatch: $Left; $Right" }
}
$names = @('nxpc','ppufiles','mkx86ins','mkx86reg','mkx86inl','mka64ins','mka64reg','msg2inc',
    'rstconv','bin2obj')
foreach ($name in $names) {
    if (-not (Test-Path -LiteralPath (Join-Path $bin ($name+'.exe')))) { throw "Missing release tool: $name" }
}
Assert-Same (Join-Path $bin 'nxpc-x86_64.exe') (Join-Path $bootstrap 'cycle3/nxpc-x86_64.exe')
Push-Location $OutputRoot
try {
    $driver = Join-Path $bin 'nxpc.exe'
    $compile = @('-n','-O2',('-Fu'+$rtl),('-FU'+$OutputRoot),('-FE'+$OutputRoot))
    Run-Step 'driver-identity' $driver @('-iW')
    $identity = Get-Content -LiteralPath (Join-Path $bootstrap 'seed/build-identity.json') -Raw | ConvertFrom-Json
    Assert-Contains 'driver-identity.log' $identity.Identity

    [IO.File]::WriteAllBytes((Join-Path $OutputRoot 'bytes.bin'),[byte[]]@(1,2,3,127))
    Run-Step 'binary-include' (Join-Path $bin 'bin2obj.exe') @('-c','ObjBytes','-o','object.inc','bytes.bin')
    Write-Fixture 'native.pas' @'
program native;
{$mode objfpc}{$H+}
uses SysUtils;
{$i object.inc}
resourcestring Greeting = 'forge-tools-ok';
begin
  if (ObjBytes[0]<>1) or (ObjBytes[3]<>127) then Halt(2);
  WriteLn(Greeting);
end.
'@
    Run-Step 'driver-compile' $driver ($compile + @('native.pas'))
    Run-Step 'driver-program' (Join-Path $OutputRoot 'native.exe') @()
    Assert-Contains 'driver-program.log' 'forge-tools-ok'
    Run-Step 'ppu-read' (Join-Path $bin 'ppufiles.exe') @('-O',(Join-Path $rtl 'sysutils.nxu'))
    Assert-Contains 'ppu-read.log' 'sysutils.o'
    Run-Step 'resource-strings' (Join-Path $bin 'rstconv.exe') @('-i','native.rsj','-o','native.po')
    Assert-Contains 'native.po' 'forge-tools-ok'
    # LLVM is the required toolchain. The compiler owns normalization and LLD
    # receives RES directly; there is no standalone resource converter.
    $null = Get-Command clang.exe, llvm-rc.exe -CommandType Application -ErrorAction Stop
    Write-Fixture 'fixture.rc' '101 RCDATA { 42 }'
    Write-Fixture 'resourceprobe.pas' @'
program ResourceProbe;
{$mode objfpc}{$H+}
uses Classes;
{$R fixture.rc}
var lStream: TResourceStream; lValue: Word;
begin
  lStream := TResourceStream.CreateFromID(HInstance, 101, PChar(10));
  try lStream.ReadBuffer(lValue, SizeOf(lValue)); finally lStream.Free; end;
  if lValue <> 42 then Halt(1);
  WriteLn('resource-ok');
end.
'@
    Run-Step 'resource-compile' $driver ($compile + @('resourceprobe.pas'))
    Run-Step 'resource-runtime' (Join-Path $OutputRoot 'resourceprobe.exe') @()
    Assert-Contains 'resource-runtime.log' 'resource-ok'

    # Native release generators must reproduce the stock-seed generator outputs.
    $generated = Join-Path $OutputRoot 'tables'
    foreach ($arch in @('i386','x86_64','x86','aarch64')) {
        $directory = Join-Path $generated $arch
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        Get-ChildItem -LiteralPath (Join-Path $bootstrap ('seed/source/'+$arch)) -Filter '*.dat' |
            Copy-Item -Destination $directory
    }
    $runs = @(
        @('mkx86ins','i386','i386'), @('mkx86ins','x86_64','x86_64'),
        @('mkx86reg','i386','i386'), @('mkx86reg','x86_64','x86_64'),
        @('mka64ins','aarch64'), @('mka64reg','aarch64'), @('mkx86inl','x86'))
    foreach ($run in $runs) {
        Push-Location (Join-Path $generated $run[1])
        try {
            $arguments = @(); if ($run.Count -gt 2) { $arguments = @($run[2]) }
            Run-Step ($run[0]+'-'+$run[1]) (Join-Path $bin ($run[0]+'.exe')) $arguments
        } finally { Pop-Location }
    }
    $generatedIncludes = @(Get-ChildItem -LiteralPath $generated -Recurse -Filter '*.inc')
    if ($generatedIncludes.Count -eq 0) { throw 'Table generators produced no includes' }
    foreach ($file in $generatedIncludes) {
        $relative = $file.FullName.Substring($generated.Length+1)
        Assert-Same $file.FullName (Join-Path $bootstrap ('seed/source/'+$relative))
    }
    Run-Step 'messages' (Join-Path $bin 'msg2inc.exe') @((Join-Path $SourceRoot 'compiler/msg/errore.msg'),'msg','msg')
    foreach ($name in @('msgidx.inc','msgtxt.inc')) { Assert-Same (Join-Path $OutputRoot $name) (Join-Path $bootstrap ('seed/source/'+$name)) }
    Write-Host "Release tools passed: $($names.Count) tools, $($steps.Count) execution steps, $($generatedIncludes.Count) matching table includes."
} finally { Pop-Location }
