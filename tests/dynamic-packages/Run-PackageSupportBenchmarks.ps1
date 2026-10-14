# Copyright (c) 2026 Kevin Collins. SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([Parameter(Mandatory)][string]$BaselineRoot,[Parameter(Mandatory)][string]$CandidateRoot,
      [Parameter(Mandatory)][string]$OutputRoot,[int]$Samples=7,[int]$CompilerSamples=3)
$ErrorActionPreference='Stop'
if($Samples -lt 3 -or $CompilerSamples -lt 3 -or $CompilerSamples -gt $Samples){throw 'Use at least three compiler samples, no more than total samples.'}
. "$PSScriptRoot/PackageTestCommon.ps1"
Initialize-PackageTests $OutputRoot
$lRoots=[ordered]@{baseline=(Resolve-Path $BaselineRoot).Path; candidate=(Resolve-Path $CandidateRoot).Path}
$lSource="$script:TestOutput/source"
Copy-Item "$PSScriptRoot/benchmarks" $lSource -Recurse
$lReport=[ordered]@{Platform=[Environment]::OSVersion.VersionString; Samples=$Samples; CompilerSamples=$CompilerSamples; Configurations=@{}; Measurements=[Collections.Generic.List[object]]::new()}
$lOptions=@{}; $lExecutables=@{}
foreach($lName in $lRoots.Keys){
    $lRoot=$lRoots[$lName]; $lCompiler="$lRoot/compiler/ppcx64.exe"; $lRTL="$lRoot/rtl/units/x86_64-win64"; $lCase="$script:TestOutput/$lName"
    New-Item -ItemType Directory -Force $lCase | Out-Null
    $lOptions[$lName]=@('-n','-O2','-B',"-Fu$lRTL","-FU$lCase","-FE$lCase")
    $lExecutables[$lName]="$lCase/package_bench.exe"
    $lReport.Configurations[$lName]=@{Root=$lRoot; CompilerSHA256=(Get-FileHash $lCompiler).Hash; SystemPPUSHA256=(Get-FileHash "$lRTL/system.nxu").Hash}
}
function Invoke-BenchmarkProcess([string]$Name,[string]$Program,[string[]]$Arguments,[bool]$Record=$true){
    $lClock=[Diagnostics.Stopwatch]::StartNew()
    # Measure the native process, excluding JSON/log bookkeeping.
    $lLog="$script:TestOutput/$Name.log"
    $ErrorActionPreference='Continue'
    & $Program @Arguments *> $lLog
    $lExit=$LASTEXITCODE; $lClock.Stop(); $ErrorActionPreference='Stop'
    if($lExit -ne 0){throw "$Name failed ($lExit); see $lLog"}
    if($Record){
        $lReport.Measurements.Add(@{Name=$Name; Seconds=$lClock.Elapsed.TotalSeconds; Program=$Program; Arguments=$Arguments})
        $lReport | ConvertTo-Json -Depth 8 | Set-Content "$script:TestOutput/timings.json" -Encoding UTF8
    }
    return [IO.File]::ReadAllText($lLog).Trim()
}
$lExpected=@{}; $lWorkloads=[ordered]@{globals=200000000; managed=2000000}
foreach($lName in $lRoots.Keys){
    $null=Invoke-BenchmarkProcess "$lName-warm-build" "$($lRoots[$lName])/compiler/ppcx64.exe" ($lOptions[$lName]+@("$lSource/package_bench.pas")) $false
    foreach($lWorkload in $lWorkloads.Keys){
        $lChecksum=Invoke-BenchmarkProcess "$lName-warm-$lWorkload" $lExecutables[$lName] @($lWorkload,[string]$lWorkloads[$lWorkload]) $false
        if($lExpected.ContainsKey($lWorkload)){Assert-PackageTest ($lExpected[$lWorkload] -ceq $lChecksum) 'Before/after runtime checksum mismatch'}
        $lExpected[$lWorkload]=$lChecksum
    }
}
for($i=0;$i -lt $Samples;$i++){
    $lNames=@('baseline','candidate'); if($i%2){[array]::Reverse($lNames)}
    foreach($lName in $lNames){
        $lCompiler="$($lRoots[$lName])/compiler/ppcx64.exe"
        $null=Invoke-BenchmarkProcess "$lName-fixture-build-$i" $lCompiler ($lOptions[$lName]+@("$lSource/package_bench.pas"))
        foreach($lWorkload in $lWorkloads.Keys){
            $lChecksum=Invoke-BenchmarkProcess "$lName-$lWorkload-$i" $lExecutables[$lName] @($lWorkload,[string]$lWorkloads[$lWorkload])
            Assert-PackageTest ($lChecksum -ceq $lExpected[$lWorkload]) 'Runtime checksum changed'
        }
        if($i -ge $CompilerSamples){continue}
        $lBuild="$script:TestOutput/$lName/compiler-$i"; New-Item -ItemType Directory -Force $lBuild | Out-Null
        $lCompilerSource="$($lRoots.candidate)/compiler"
        $lArgs=$lOptions[$lName][0..3]+@('-dx86_64',"-FU$lBuild","-FE$lBuild")
        foreach($lPart in @('','x86_64','x86','systems')){$lArgs+="-Fu$lCompilerSource/$lPart","-Fi$lCompilerSource/$lPart"}
        $null=Invoke-BenchmarkProcess "$lName-compiler-build-$i" $lCompiler ($lArgs+@("$lCompilerSource/pp.pas"))
        $null=Invoke-BenchmarkProcess "$lName-compiler-version-$i" "$lBuild/pp.exe" @('-iV') $false
    }
    Write-Host "PASS timing sample $($i+1)"
}
$lSummary=@{}
foreach($lWorkload in @('fixture-build','compiler-build','globals','managed')){
    $lSummary[$lWorkload]=@{}
    foreach($lName in $lRoots.Keys){
        $lValues=@($lReport.Measurements | Where-Object {$_.Name.StartsWith("$lName-$lWorkload-")} | ForEach-Object Seconds | Sort-Object)
        $lMiddle=[int][Math]::Floor($lValues.Count/2)
        $lMedian=if($lValues.Count%2){$lValues[$lMiddle]}else{($lValues[$lMiddle-1]+$lValues[$lMiddle])/2}
        $lSummary[$lWorkload][$lName]=@{Median=$lMedian; Minimum=$lValues[0]; Maximum=$lValues[-1]}
    }
    $lSummary[$lWorkload].PercentChange=100*($lSummary[$lWorkload].candidate.Median/$lSummary[$lWorkload].baseline.Median-1)
}
$lReport.Summary=$lSummary; $lReport.Checksums=$lExpected; $lReport.ExecutableBytes=@{}
foreach($lName in $lExecutables.Keys){$lReport.ExecutableBytes[$lName]=(Get-Item $lExecutables[$lName]).Length}
$lReport | ConvertTo-Json -Depth 8 | Set-Content "$script:TestOutput/timings.json" -Encoding UTF8
$lSummary | ConvertTo-Json -Depth 5 | Write-Host
