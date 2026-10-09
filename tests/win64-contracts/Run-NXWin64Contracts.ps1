# Copyright (c) 2026 Kevin Collins.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses",
# as defined by the Mozilla Public License, v. 2.0.
#
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$OutputRoot = (Join-Path $env:TEMP ('nxwc-' + [guid]::NewGuid().ToString('N').Substring(0,8)))
)
$ErrorActionPreference = 'Stop'
if (-not $SourceRoot) { $SourceRoot = Join-Path $PSScriptRoot '..\..' }
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
$compiler = Join-Path $SourceRoot 'compiler\ppcx64.exe'
$units = Join-Path $SourceRoot 'rtl\units\x86_64-win64'
$fpcres = Join-Path $SourceRoot 'utils\fpcres\bin\x86_64-win64\fpcres.exe'
$tools = @{}
foreach ($name in @('clang','lld-link','llvm-dlltool','llvm-rc','llvm-readobj')) {
    $tools[$name] = (Get-Command ($name+'.exe') -ErrorAction Stop).Source
}
if ((Split-Path $tools['lld-link']) -ne (Split-Path $tools['clang'])) {
    throw 'Clang and LLD must come from the same LLVM bin directory used by FPC -FD.'
}
foreach ($path in @($compiler, "$units\system.ppu", $fpcres)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing matched build artifact: $path" }
}
if ((& $compiler -iTP) -ne 'x86_64' -or (& $compiler -iTO) -ne 'win64') { throw 'Requires native Win64 compiler' }
if (Test-Path -LiteralPath $OutputRoot) {
    if (@(Get-ChildItem -LiteralPath $OutputRoot -Force).Count) { throw 'OutputRoot must be empty; generated fixtures must not reuse stale outputs.' }
}
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$steps = [Collections.Generic.List[object]]::new()
function Invoke-Step([string]$Name, [string]$Executable, [string[]]$Arguments, [int]$ExpectedExitCode = 0) {
    $log = Join-Path $OutputRoot ($Name+'.log')
    $ErrorActionPreference = 'Continue'
    & $Executable @Arguments *> $log
    $code = $LASTEXITCODE
    $steps.Add([pscustomobject]@{ Step=$Name; Executable=$Executable; Arguments=$Arguments; ExitCode=$code; ExpectedExitCode=$ExpectedExitCode; Log=$log })
    $steps.ToArray() | ConvertTo-Json -Depth 5 | Set-Content "$OutputRoot\steps.json"
    if ($code -ne $ExpectedExitCode) {
        Get-Content $log -Tail 25 | Write-Host
        throw "$Name failed ($code). Log: $log"
    }
    Write-Host "PASS $Name"
}
. "$PSScriptRoot\Test-NXContractImage.ps1"
$oldPath = $env:PATH
try {
    $env:PATH = (Split-Path $tools['clang'])+';'+$oldPath
    Push-Location $OutputRoot
    try {
        foreach ($tool in @('clang','lld-link','llvm-readobj')) { Invoke-Step ($tool+'-version') $tools[$tool] @('--version') }
        Invoke-Step 'compiler-version' $compiler @('-iV')
        Get-FileHash -LiteralPath @($compiler, "$units\system.ppu", "$units\sysutils.ppu", "$units\windows.ppu", $fpcres) -Algorithm SHA256 |
            Select-Object Path, Hash |
            ConvertTo-Json | Set-Content "$OutputRoot\build-inputs.json"
        Copy-Item "$PSScriptRoot\*.pas", "$PSScriptRoot\*.lpr", "$PSScriptRoot\*.c" $OutputRoot
        $common = @('-n','-B','-O2','-g','-Xm',('-Fu'+$units),('-Fu'+$OutputRoot),('-FU'+$OutputRoot),('-FE'+$OutputRoot),('-FD'+(Split-Path $tools['clang'])))
        $smart = $common + @('-CX','-XX')
        Invoke-Step 'foreign-bridge' $tools['clang'] @('--target=x86_64-pc-windows-msvc','-c','-O1','-fno-stack-protector','-funwind-tables','foreign_bridge.c','-o','foreign_bridge.obj')
        foreach ($module in @('One','Two')) {
            $id = if ($module -eq 'One') {1} else {2}
            "101 RCDATA { $id }" | Set-Content fixture.rc
            Invoke-Step ('resource-'+$module) $tools['llvm-rc'] @('/FO','fixture.res','fixture.rc')
            Invoke-Step ('resource-coff-'+$module) $fpcres @('-o','fixture.o','-a','x86_64','-of','coff','fixture.res')
            $arguments = $smart + @('-WR','-WB180000000',('-onxContract'+$module+'.dll'))
            if ($module -eq 'Two') { $arguments += '-dMODULE_TWO' }
            Invoke-Step ('dll-'+$module) $compiler ($arguments + @('nxContractLibrary.lpr'))
        }
        Invoke-Step 'normal-exe-build' $compiler ($common + @('-WN','-onxContractNormal.exe','nxContractExecutable.lpr'))
        Invoke-Step 'fixed-exe-build' $compiler ($smart + @('-WN','-onxContractFixed.exe','nxContractExecutable.lpr'))
        Invoke-Step 'relocatable-exe-build' $compiler ($smart + @('-WR','-onxContractReloc.exe','nxContractExecutable.lpr'))
        Invoke-Step 'smartlink-input-symbols' $tools['llvm-readobj'] @('--symbols','utNXContractLifecycle.o')
        if ([IO.File]::ReadAllText("$OutputRoot\smartlink-input-symbols.log") -notmatch 'Name: NX_DISCARD_ME') {
            throw 'Discard fixture symbol was not emitted into the input object'
        }
        $summaries = @()
        foreach ($image in @('nxContractOne.dll','nxContractTwo.dll','nxContractFixed.exe','nxContractReloc.exe','nxContractNormal.exe')) {
            Invoke-Step ('metadata-'+$image) $tools['llvm-readobj'] @('--file-headers','--sections','--coff-imports','--coff-exports','--coff-basereloc','--coff-tls-directory','--unwind',$image)
            $summaries += Test-NXContractImage "$OutputRoot\$image" ($image.EndsWith('.dll')) ($image.EndsWith('.dll') -or $image -eq 'nxContractReloc.exe')
            $map = [IO.Path]::ChangeExtension($image,'.map')
            if (-not (Test-Path $map)) { throw "Missing link map $map" }
            if ([IO.File]::ReadAllText("$OutputRoot\$map") -match 'NX_DISCARD_ME') { throw "$image : dead smartlink section retained" }
        }
        $summaries | ConvertTo-Json -Depth 6 | Set-Content "$OutputRoot\pe-contracts.json"
        @('LIBRARY KERNEL32.dll','EXPORTS','LoadLibraryA','GetCommandLineA','GetProcAddress','FreeLibrary','VirtualAlloc','VirtualFree','CreateEventA','SetEvent','WaitForSingleObject','CreateThread','CloseHandle','GetStdHandle','WriteFile','ExitProcess') | Set-Content kernel32.def
        Invoke-Step 'foreign-import-library' $tools['llvm-dlltool'] @('-m','i386:x86-64','-d','kernel32.def','-l','kernel32.lib')
        Invoke-Step 'foreign-caller-build' $tools['clang'] @('--target=x86_64-pc-windows-msvc','-c','-O1','-fno-builtin','-fno-stack-protector','foreign_caller.c','-o','foreign_caller.obj')
        Invoke-Step 'foreign-caller-link' $tools['lld-link'] @('/machine:x64','/nodefaultlib','/subsystem:console','/entry:mainCRTStartup','/out:nxForeignCaller.exe','foreign_caller.obj','kernel32.lib')
        Invoke-Step 'normal-exe-run' "$OutputRoot\nxContractNormal.exe" @()
        Invoke-Step 'fixed-exe-run' "$OutputRoot\nxContractFixed.exe" @()
        Invoke-Step 'relocatable-exe-run' "$OutputRoot\nxContractReloc.exe" @()
        Invoke-Step 'pointer-data-build' $tools['clang'] @('--target=x86_64-pc-windows-msvc','-c','-O1','pointer_data.c','-o','pointer_data.obj')
        $pointerArgs = $smart + @('-gh')
        Invoke-Step 'pointer-exe-build' $compiler ($pointerArgs + @('-onxPointerChecks.exe','nxPointerChecks.lpr'))
        Invoke-Step 'pointer-dll-build' $compiler ($pointerArgs + @('-WR','-WB180000000','-onxPointerLibrary.dll','nxPointerLibrary.lpr'))
        Invoke-Step 'pointer-valid-exe-run' "$OutputRoot\nxPointerChecks.exe" @('valid')
        foreach ($case in 1..10) {
            Invoke-Step ('pointer-reject-'+$case) "$OutputRoot\nxPointerChecks.exe" @($case.ToString()) 204
            $text = [IO.File]::ReadAllText("$OutputRoot\pointer-reject-$case.log")
            if ($text -notmatch "CHECK invalid pointer case $case\b" -or $text -notmatch 'Runtime error 204') {
                throw "Pointer case $case lacks the actual CheckPointer fatal-error witness"
            }
        }
        Invoke-Step 'foreign-caller-run' "$OutputRoot\nxForeignCaller.exe" @()
        foreach ($case in 1..10) {
            Invoke-Step ('pointer-dll-reject-'+$case) "$OutputRoot\nxForeignCaller.exe" @("--pointer-case=$case") 204
            $text = [IO.File]::ReadAllText("$OutputRoot\pointer-dll-reject-$case.log")
            if ($text -notmatch 'PASS pointer child DLL relocated to 0x' -or
                $text -notmatch "CHECK invalid pointer case $case\b" -or $text -notmatch 'Runtime error 204') {
                throw "DLL pointer case $case lacks relocation, positive-control or fatal-error evidence"
            }
        }
        Write-Host "Win64/LLD contracts passed. Evidence: $OutputRoot"
    } finally { Pop-Location }
} finally { $env:PATH = $oldPath }
