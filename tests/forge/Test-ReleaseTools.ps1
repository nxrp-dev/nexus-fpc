# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
[CmdletBinding()]
param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot '../..'),
    [string]$OutputRoot
)
$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$bootstrap = Join-Path $SourceRoot 'build/forge-bootstrap'
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
$names = @('fpc','ppufiles','ppumove','mkx86ins','mkx86reg','mkx86inl','mka64ins','mka64reg','msg2inc',
    'data2inc','ppdep','rstconv','bin2obj','postw32','fpcres','fpcreslipo','plex','pyacc')
foreach ($name in $names) {
    if (-not (Test-Path -LiteralPath (Join-Path $bin ($name+'.exe')))) { throw "Missing release tool: $name" }
}
Assert-Same (Join-Path $bin 'ppcx64.exe') (Join-Path $bootstrap 'cycle3/ppcx64.exe')
Push-Location $OutputRoot
try {
    $driver = Join-Path $bin 'fpc.exe'
    $compile = @('-n','-O2',('-Fu'+$rtl),('-FU'+$OutputRoot),('-FE'+$OutputRoot))
    Run-Step 'driver-identity' $driver @('-iW')
    $identity = Get-Content -LiteralPath (Join-Path $bootstrap 'seed/build-identity.json') -Raw | ConvertFrom-Json
    Assert-Contains 'driver-identity.log' $identity.Identity

    [IO.File]::WriteAllBytes((Join-Path $OutputRoot 'bytes.bin'),[byte[]]@(1,2,3,127))
    Run-Step 'data-include' (Join-Path $bin 'data2inc.exe') @('-b','-s','bytes.bin','data.inc','DataBytes')
    Run-Step 'binary-include' (Join-Path $bin 'bin2obj.exe') @('-c','ObjBytes','-o','object.inc','bytes.bin')
    Write-Fixture 'native.pas' @'
program native;
{$mode objfpc}{$H+}
uses SysUtils;
{$i data.inc}
{$i object.inc}
resourcestring Greeting = 'forge-tools-ok';
begin
  if (Ord(DataBytes[0,1])<>1) or (Ord(DataBytes[0,4])<>127) then Halt(1);
  if (ObjBytes[0]<>1) or (ObjBytes[3]<>127) then Halt(2);
  WriteLn(Greeting);
end.
'@
    Run-Step 'driver-compile' $driver ($compile + @('native.pas'))
    Run-Step 'driver-program' (Join-Path $OutputRoot 'native.exe') @()
    Assert-Contains 'driver-program.log' 'forge-tools-ok'
    Run-Step 'ppu-read' (Join-Path $bin 'ppufiles.exe') @('-O',(Join-Path $rtl 'sysutils.ppu'))
    Assert-Contains 'ppu-read.log' 'sysutils.o'
    Run-Step 'ppumove-help' (Join-Path $bin 'ppumove.exe') @('-h')
    Run-Step 'postw32-help' (Join-Path $bin 'postw32.exe') @('--help')
    Run-Step 'resource-strings' (Join-Path $bin 'rstconv.exe') @('-i','native.rsj','-o','native.po')
    Assert-Contains 'native.po' 'forge-tools-ok'
    Write-Fixture 'depunit.pas' "unit depunit;`ninterface`nimplementation`nend.`n"
    Write-Fixture 'dependency.pas' "program dependency;`nuses depunit;`nbegin`nend.`n"
    Run-Step 'dependencies' (Join-Path $bin 'ppdep.exe') @('dependency.pas')
    Assert-Contains 'dependencies.log' 'depunit'

    Write-Fixture 'fixture.rc' '101 RCDATA { 42 }'
    Run-Step 'resource-parse' (Join-Path $bin 'fpcres.exe') @('-of','res','-o','fixture.res','fixture.rc')
    Run-Step 'resource-coff' (Join-Path $bin 'fpcres.exe') @('-of','coff','-a','x86_64','-o','fixture.o','fixture.res')
    foreach ($endian in @('littleendian','bigendian')) {
        Run-Step ('resource-'+$endian) (Join-Path $bin 'fpcres.exe') @('-of','external','-a',$endian,'-o',($endian+'.fpcres'),'fixture.res')
    }
    Run-Step 'resource-share' (Join-Path $bin 'fpcreslipo.exe') @('littleendian.fpcres','bigendian.fpcres','-o','shared.fpcres')
    if ((Get-Item -LiteralPath 'shared.fpcres').Length -eq 0) { throw 'Empty shared resource output' }

    Write-Fixture 'lexer.l' @'
%{
program lexer;
uses lexlib;
%}
%%
[0-9]+  return(7);
"ok"    return(8);
.       ;
%%
begin
  Assign(yyinput, 'lexer.input'); Reset(yyinput);
  if yylex<>7 then Halt(1);
  if yytext<>'123' then Halt(2);
  if yylex<>8 then Halt(3);
  if yytext<>'ok' then Halt(4);
  Close(yyinput);
end.
'@
    Write-Fixture 'lexer.input' '123 ok '
    Write-Fixture 'parser.y' @'
%{
program parser;
uses yacclib;
var supplied: Boolean;
%}
%token NUMBER
%%
input: NUMBER ;
%%
function yylex: Integer;
begin
  if supplied then yylex:=0 else begin supplied:=True; yylex:=NUMBER; end;
end;
begin
  supplied:=False;
  if yyparse<>0 then Halt(1);
end.
'@
    $parserUnits = '-Fu'+(Join-Path $bootstrap 'tools/packages/tplylib/src')
    foreach ($kind in @('lexer','parser')) {
        $generator = if ($kind -eq 'lexer') { 'plex.exe' } else { 'pyacc.exe' }
        $inputFile = if ($kind -eq 'lexer') { 'lexer.l' } else { 'parser.y' }
        Run-Step ($kind+'-generate') (Join-Path $bin $generator) @($inputFile,($kind+'.pas'))
        Run-Step ($kind+'-compile') $driver ($compile + @('-Sg',$parserUnits,($kind+'.pas')))
        Run-Step ($kind+'-run') (Join-Path $OutputRoot ($kind+'.exe')) @()
    }

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
