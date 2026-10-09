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
    [string]$Compiler,
    [string]$OutputRoot = (Join-Path $env:TEMP ('nx-unit-exports-' + [guid]::NewGuid().ToString('N').Substring(0,8)))
)
$ErrorActionPreference = 'Stop'
if (-not $SourceRoot) { $SourceRoot = Join-Path $PSScriptRoot '..\..' }
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
if (-not $Compiler) { $Compiler = Join-Path $SourceRoot 'compiler\ppcx64.exe' }
$units = Join-Path $SourceRoot 'rtl\units\x86_64-win64'
$readobj = (Get-Command llvm-readobj.exe -ErrorAction Stop).Source
$toolDir = Split-Path $readobj
if ((& $Compiler -iTP) -ne 'x86_64' -or (& $Compiler -iTO) -ne 'win64') { throw 'Requires native Win64 compiler' }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $OutputRoot) { throw 'OutputRoot must be new' }
New-Item -ItemType Directory -Path $OutputRoot | Out-Null
$steps = [Collections.Generic.List[object]]::new()
function Invoke-Step([string]$Name, [string]$Executable, [string[]]$Arguments) {
    $log = Join-Path $OutputRoot ($Name+'.log')
    & $Executable @Arguments *> $log
    $code = $LASTEXITCODE
    $steps.Add([pscustomobject]@{ Step=$Name; Executable=$Executable; Arguments=$Arguments; ExitCode=$code; Log=$log })
    $steps.ToArray() | ConvertTo-Json -Depth 5 | Set-Content "$OutputRoot\steps.json"
    if ($code -ne 0) { throw "$Name failed ($code). Log: $log" }
    Write-Host "PASS $Name"
}
foreach ($mode in @('normal','smart')) {
    $caseDir = Join-Path $OutputRoot $mode
    New-Item -ItemType Directory -Path $caseDir | Out-Null
    Copy-Item "$PSScriptRoot\*.pas", "$PSScriptRoot\*.lpr" $caseDir
    Push-Location $caseDir
    try {
        $common = @('-n','-O2','-Cr','-Co','-Ci',('-Fu'+$units),('-Fu'+$caseDir),('-FU'+$caseDir),('-FE'+$caseDir),('-FD'+$toolDir))
        if ($mode -eq 'smart') { $common += @('-CX','-XX') }
        Invoke-Step "$mode-standalone-unit" $Compiler ($common + @('-B','utNXPrivateExports.pas'))
        foreach ($kind in @('exe','dll')) {
            $source = if ($kind -eq 'exe') {'nxUnitExports.lpr'} else {'nxUnitExportsLibrary.lpr'}
            $image = if ($kind -eq 'exe') {'nxUnitExports.exe'} else {'nxUnitExportsLibrary.dll'}
            $states = if ($kind -eq 'exe') {@('standalone','cold','cached')} else {@('cold','cached')}
            foreach ($state in $states) {
                $isCached = $state -ne 'cold'
                $step = "$mode-$kind-$state"
                $arguments = $common + @(('-o'+$image),$source)
                if ($state -eq 'cold') { $arguments += '-B' }
                $unitFiles = @("$caseDir\utNXPrivateExports.ppu", "$caseDir\utNXPrivateExports.o")
                if ($isCached) {
                    $before = Get-FileHash -LiteralPath $unitFiles
                    Move-Item -LiteralPath 'utNXPrivateExports.pas' -Destination 'utNXPrivateExports.pas.hidden'
                }
                try { Invoke-Step "$step-build" $Compiler $arguments }
                finally {
                    if ($isCached) { Move-Item -LiteralPath 'utNXPrivateExports.pas.hidden' -Destination 'utNXPrivateExports.pas' }
                }
                if ($isCached) {
                    $after = Get-FileHash -LiteralPath $unitFiles
                    if (Compare-Object ($before.Hash) ($after.Hash)) { throw 'Cached unit was modified' }
                }
                Invoke-Step "$step-exports" $readobj @('--coff-exports',$image)
                $metadata = Get-Content "$OutputRoot\$step-exports.log" -Raw
                foreach ($name in @('NX_PrivateMarker','NX_PrivateData','NX_AutomaticMarker','NX_MainMarker')) {
                    if ($metadata -notmatch "Name: $name(?:\r?\n)") { throw "$step missing $name" }
                }
                $runtimeArgs = if ($kind -eq 'dll') {@((Join-Path $caseDir $image))} else {@()}
                Invoke-Step "$step-run" (Join-Path $caseDir 'nxUnitExports.exe') $runtimeArgs
            }
        }
    } finally { Pop-Location }
}
Write-Host "PASS unit exports. Results: $OutputRoot"
