# Copyright (c) 2026 Kevin Collins. SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([Parameter(Mandatory)][string]$SdkRoot,[Parameter(Mandatory)][string]$OutputRoot,
      [string]$SourceRoot=(Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference='Stop'
. "$PSScriptRoot/PackageTestCommon.ps1"
Initialize-PackageTests $OutputRoot
$SdkRoot=(Resolve-Path $SdkRoot).Path; $SourceRoot=(Resolve-Path $SourceRoot).Path
$lCompiler="$SdkRoot/bin/ppcx64.exe"
$null=Invoke-TestProcess 'build-probe' $lCompiler ((Get-TestCompilerOptions $SdkRoot $script:TestOutput)+@("$PSScriptRoot/package_native_probe.pas"))
$null=Invoke-TestProcess 'build-lifecycle' $lCompiler ((Get-TestCompilerOptions $SdkRoot $script:TestOutput)+@("-Fu$SourceRoot/rtl/inc","$PSScriptRoot/package_lifecycle_test.pas"))
$null=Invoke-TestProcess 'run-lifecycle' "$script:TestOutput/package_lifecycle_test.exe"
$lPPU=Get-Content "$SourceRoot/compiler/ppu.pas" -Raw
$lVersion=[uint64][regex]::Match($lPPU,'CurrentPPUVersion\s*=\s*(\d+)').Groups[1].Value
$lRevision=[uint64][regex]::Match($lPPU,'CurrentPPULongVersion\s*=\s*(\d+)').Groups[1].Value
$lIdentity=($lVersion -shl 48) -bor ([uint64]0xc181 -shl 32) -bor $lRevision
foreach($lSmart in @($false,$true)) {
    foreach($lCached in @($false,$true)) {
        $lName=$(if($lSmart){'smart'}else{'normal'})+$(if($lCached){'-cached'}else{'-fresh'})
        $lCase="$script:TestOutput/$lName"; $lDist="$lCase/distribution"
        New-Item -ItemType Directory -Force $lDist | Out-Null
        function Package([string]$Name,[string[]]$Requires,[Collections.IDictionary]$Units) {
            $lDirectory="$lCase/$Name"
            foreach($lUnit in $Units.Keys){Write-TestFile "$lDirectory/$lUnit.pas" $Units[$lUnit]}
            $lOptions=(Get-TestCompilerOptions $SdkRoot $lDirectory $lSmart)+@("-Fp$lDist","-Fl$lDist","-Fu$lDirectory","-Fi$SourceRoot/rtl/inc")
            $lHashes=@{}
            if($lCached){
                foreach($lUnit in $Units.Keys){
                    $lRequired=@($Requires | ForEach-Object {"-FP$_"})
                    $null=Invoke-TestProcess "$lName-$Name-$lUnit" $lCompiler ($lOptions+$lRequired+@("$lDirectory/$lUnit.pas"))
                }
                foreach($lUnit in $Units.Keys){
                    $lHashes[$lUnit]=Get-TestUnitHash $lDirectory $lUnit
                    Move-TestArtifact "$lDirectory/$lUnit.pas" "$lDirectory/$lUnit.pas.hidden"
                }
            }
            $lDeclaration="package $Name; "
            if($Requires.Count){$lDeclaration+='requires '+($Requires -join ',')+'; '}
            $lDeclaration+='contains '+($Units.Keys -join ',')+'; end.'
            Write-TestFile "$lDirectory/$Name.ppk" $lDeclaration
            $null=Invoke-TestProcess "$lName-$Name" $lCompiler ($lOptions+@("$lDirectory/$Name.ppk"))
            foreach($lUnit in $lHashes.Keys){Assert-PackageTest ($lHashes[$lUnit] -eq (Get-TestUnitHash $lDirectory $lUnit)) "$lUnit cached artifacts changed"}
            foreach($lSuffix in @('.nxp','.dll')){Copy-Item "$lDirectory/$Name$lSuffix" $lDist}
            foreach($lUnit in $Units.Keys){Hide-TestUnit $lDirectory $lUnit}
        }
        Package nxrtl @() ([ordered]@{fpcpackage=(Get-Content "$SourceRoot/rtl/inc/fpcpackage.pp" -Raw)})
        $lUnused=@'
unit uunused;
{$mode objfpc}{$H+}
interface
implementation
uses upackageruntime;
threadvar Value: LongInt;
const UnusedWide: WideString = 'unused owner';
initialization
  Value:=71;
  UnusedReady:=(Value=71) and (UnusedWide='unused owner');
  Trace:=Trace+'U';
finalization
  WriteLn('FINAL U'); Flush(Output);
end.
'@
        Package pkgshared @('nxrtl') ([ordered]@{upackageruntime=(Get-Content "$PSScriptRoot/upackageruntime.pas" -Raw); uunused=$lUnused})
        foreach($lSide in @(@('left','L'),@('right','R'))){
            $lUnit='u'+$lSide[0]; $lLetter=$lSide[1]
            Package ('pkg'+$lSide[0]) @('nxrtl','pkgshared') ([ordered]@{
                $lUnit="unit $lUnit; interface implementation uses upackageruntime; initialization Trace:=Trace+'$lLetter'; finalization WriteLn('FINAL $lLetter'); Flush(Output); end."
            })
        }
        Package pkgfail @('nxrtl','pkgshared') ([ordered]@{
            ufailfirst="unit ufailfirst; interface implementation uses upackageruntime; initialization Trace:=Trace+'F'; finalization Trace:=Trace+'f'; end."
            ufailsecond="unit ufailsecond; interface implementation uses ufailfirst, upackageruntime; initialization Trace:=Trace+'!'; raise EPackageProbe.Create('initialization failure'); end."
        })
        $lExports=@{}
        foreach($lDLL in Get-ChildItem "$lDist/*.dll"){
            $lText=Invoke-TestProcess "$lName-$($lDLL.BaseName)-exports" llvm-readobj.exe @('--coff-exports',$lDLL.FullName)
            $lExports[$lDLL.Name]=@([regex]::Matches($lText,'(?m)^\s*Name: (.+)$') | ForEach-Object {$_.Groups[1].Value.Trim()})
        }
        function Check-Imports([string]$Image){
            $lText=Invoke-TestProcess "$lName-$([IO.Path]::GetFileNameWithoutExtension($Image))-imports" llvm-readobj.exe @('--coff-imports',$Image)
            foreach($lBlock in [regex]::Matches($lText,'(?s)Import \{(.*?)\n\}')){
                $lOwner=[regex]::Match($lBlock.Value,'Name: (.+)').Groups[1].Value.Trim()
                if($lExports.ContainsKey($lOwner)){
                    foreach($lSymbol in [regex]::Matches($lBlock.Value,'(?m)^\s*Symbol: (.+) \(\d+\)')){
                        Assert-PackageTest ($lExports[$lOwner] -ccontains $lSymbol.Groups[1].Value) "Missing export from $lOwner : $($lSymbol.Groups[1].Value)"
                    }
                }
            }
        }
        foreach($lDLL in Get-ChildItem "$lDist/*.dll"){Check-Imports $lDLL.FullName}
        $null=Invoke-TestProcess "$lName-inspect" "$script:TestOutput/package_native_probe.exe" @('descriptor',$lDist,[string]$lIdentity) 0 'PASS descriptors'
        $lHost="$lCase/host"
        New-Item -ItemType Directory -Force $lHost | Out-Null
        $lOptions=(Get-TestCompilerOptions $SdkRoot $lHost $lSmart)+@("-Fp$lDist","-Fl$lDist",'-FPnxrtl','-FPpkgshared','-FPpkgleft','-FPpkgright',"-Fu$lHost")
        $null=Invoke-TestProcess "$lName-startup" $lCompiler ($lOptions+@("$SourceRoot/rtl/win64/sysinitpkg.pp"))
        Write-TestFile "$lHost/uhost.pas" "unit uhost; interface implementation uses upackageruntime; initialization Trace:=Trace+'H'; finalization WriteLn('FINAL H'); Flush(Output); end."
        $null=Invoke-TestProcess "$lName-host-build" $lCompiler ($lOptions+@("$PSScriptRoot/package_runtime_host.pas"))
        Check-Imports "$lHost/package_runtime_host.exe"
        Copy-Item "$lDist/*.dll" $lHost
        $lActual=Invoke-TestProcess "$lName-host-run" "$lHost/package_runtime_host.exe" @() 0 '' $lHost
        $lExpected=@('PASS shared RTL: identity, allocation, managed values, exception, resources','FINAL H','FINAL R','FINAL L','FINAL U','FINAL A') -join "`n"
        Assert-PackageTest ($lActual.Replace("`r",'').Trim() -ceq $lExpected) 'Unexpected package lifecycle order'
        foreach($lUnit in @('fpcpackage','upackageruntime','uunused','uleft','uright')){
            Assert-PackageTest (-not(Test-Path "$lHost/$lUnit.nxu")) "Standalone PPU leaked: $lUnit"
        }
    }
}
Write-Host "PASS package runtime suite ($($script:TestSteps.Count) steps)"
