# Copyright (c) 2026 Kevin Collins. SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([Parameter(Mandatory)][string]$SdkRoot,[Parameter(Mandatory)][string]$OutputRoot)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/PackageTestCommon.ps1"
Initialize-PackageTests $OutputRoot
$SdkRoot=(Resolve-Path $SdkRoot).Path
$lCompiler="$SdkRoot/bin/nxpc-x86_64.exe"
$lProbe="$script:TestOutput/package_native_probe.exe"
$null=Invoke-TestProcess 'build-probe' $lCompiler ((Get-TestCompilerOptions $SdkRoot $script:TestOutput)+@("$PSScriptRoot/package_native_probe.pas"))
foreach ($lSmart in @($false,$true)) {
    foreach ($lCached in @($false,$true)) {
        $lName=$(if($lSmart){'smart'}else{'normal'})+$(if($lCached){'-cached'}else{'-fresh'})
        $lCase="$script:TestOutput/$lName"; $lProvider="$lCase/provider"; $lConsumer="$lCase/consumer"; $lDist="$lCase/distribution"
        New-Item -ItemType Directory -Force $lProvider,$lConsumer,$lDist | Out-Null
        function Compile([string]$Label,[string]$Directory,[string]$Filename,[bool]$Packages=$false,[int]$Expected=0,[string]$Contains='',[string[]]$Extra=@()) {
            $lOptions=Get-TestCompilerOptions $SdkRoot $Directory $lSmart
            if($Packages){$lOptions+="-Fp$lDist","-Fl$lDist"}
            $null=Invoke-TestProcess "$lName-$Label" $lCompiler ($lOptions+$Extra+@("$Directory/$Filename")) $Expected $Contains $Directory
        }
        Copy-Item "$PSScriptRoot/upackagebase.pas" $lProvider
        Write-TestFile "$lProvider/pkgbase.nxpk" 'package pkgbase; contains upackagebase; end.'
        if($lCached){
            Compile 'base-unit' $lProvider 'upackagebase.pas'
            $lBefore=Get-TestUnitHash $lProvider upackagebase
            Move-TestArtifact "$lProvider/upackagebase.pas" "$lProvider/upackagebase.pas.hidden"
        }
        Compile 'base-package' $lProvider 'pkgbase.nxpk'
        if($lCached){Assert-PackageTest ($lBefore -eq (Get-TestUnitHash $lProvider upackagebase)) 'Cached provider changed'}
        foreach($lSuffix in @('.nxp','.dll')){Copy-Item "$lProvider/pkgbase$lSuffix" $lDist}
        Hide-TestUnit $lProvider upackagebase
        Copy-Item "$PSScriptRoot/upackageconsumer.pas" $lConsumer
        Write-TestFile "$lConsumer/pkgconsumer.nxpk" 'package pkgconsumer; requires pkgbase; contains upackageconsumer; end.'
        if($lCached){
            Compile 'consumer-unit' $lConsumer 'upackageconsumer.pas' $true 0 '' @('-FPpkgbase')
            $lBefore=Get-TestUnitHash $lConsumer upackageconsumer
            Move-TestArtifact "$lConsumer/upackageconsumer.pas" "$lConsumer/upackageconsumer.pas.hidden"
        }
        Compile 'consumer-package' $lConsumer 'pkgconsumer.nxpk' $true
        if($lCached){Assert-PackageTest ($lBefore -eq (Get-TestUnitHash $lConsumer upackageconsumer)) 'Cached consumer changed'}
        Assert-PackageTest (-not(Test-Path "$lConsumer/upackagebase.nxu")) 'Provider unit leaked into consumer'
        foreach($lSuffix in @('.nxp','.dll')){Copy-Item "$lConsumer/pkgconsumer$lSuffix" $lDist}
        $lExports=Invoke-TestProcess "$lName-exports" llvm-readobj.exe @('--coff-exports',"$lDist/pkgbase.dll")
        $lImports=Invoke-TestProcess "$lName-imports" llvm-readobj.exe @('--coff-imports',"$lDist/pkgconsumer.dll")
        $lExported=@([regex]::Matches($lExports,'(?m)^\s*Name: (.+)$') | ForEach-Object {$_.Groups[1].Value.Trim()})
        $lImported=@([regex]::Matches($lImports,'(?m)^\s*Symbol: (.+) \(\d+\)') | ForEach-Object {$_.Groups[1].Value})
        Assert-PackageTest ($lExported -ccontains 'NX_BaseCounter') 'Missing public alias'
        Assert-PackageTest ($lImports.Contains('Name: pkgbase.dll') -and $lImported.Count -gt 0) 'Missing provider import'
        foreach($lSymbol in $lImported){Assert-PackageTest ($lExported -ccontains $lSymbol) "Unexported import $lSymbol"}
        foreach($lSymbol in @('VMT_$UPACKAGEBASE_$$_TPACKAGECLASS','RTTI_$UPACKAGEBASE_$$_TPACKAGECLASS',
            'RTTI_$UPACKAGEBASE_$$_TPACKAGEENUM','RTTI_$UPACKAGEBASE_$$_TPACKAGERECORD','INIT_$UPACKAGEBASE_$$_TPACKAGERECORD',
            'fpc_initialize','fpc_finalize','__FPC_specific_handler','RESSTR_$UPACKAGEBASE_$$_PACKAGETEXT',
            'UPACKAGEBASE_$$_BASECOUNTER$$POINTER','UPACKAGEBASE_$$_HIDDENHELPER$LONGINT$$LONGINT','UPACKAGEBASE_$$_ADD$LONGINT$$LONGINT')){
            Assert-PackageTest ($lImported -ccontains $lSymbol) "Missing import $lSymbol"
        }
        $null=Invoke-TestProcess "$lName-runtime" $lProbe @('link',$lDist) 0 'PASS runtime symbols'
        if(-not $lSmart -and -not $lCached){
            foreach($lNegative in @(
                @('empty','package empty; end.','does not contain or require the System unit'),
                @('missing','package missing; contains no_such_unit;',"Can't find unit"),
                @('duplicate','package duplicate; requires pkgbase; contains upackagebase; end.','is already contained in package pkgbase'))){
                Write-TestFile "$lConsumer/$($lNegative[0]).nxpk" $lNegative[1]
                Compile $lNegative[0] $lConsumer "$($lNegative[0]).nxpk" $true 1 $lNegative[2]
            }
        }
    }
}
Write-Host "PASS package link suite ($($script:TestSteps.Count) steps)"
