# Copyright (c) 2026 Kevin Collins. SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([Parameter(Mandatory)][string]$SdkRoot,[Parameter(Mandatory)][string]$OutputRoot,[switch]$SmartLink)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/PackageTestCommon.ps1"
Initialize-PackageTests $OutputRoot
$lRoot=(Resolve-Path "$PSScriptRoot/../..").Path; $SdkRoot=(Resolve-Path $SdkRoot).Path
. "$lRoot/scripts/NexusFPCPackageArtifacts.ps1"
$lLate="$script:TestOutput/late"
$null=Invoke-TestScript late-examples "$lRoot/scripts/Build-NexusFPCLatePackageExamples.ps1" @{
    SdkRoot=$SdkRoot; OutputRoot=$lLate; RunExamples=$true; SmartLink=[bool]$SmartLink
}
$lProviders=Get-NexusPackageBundle "$lLate/packages"
foreach($lKind in @('console','gui')){
    $lBundle=Get-NexusPackageBundle "$lLate/late_$lKind"; $lExe="late_$lKind.exe"
    $lImports=Invoke-TestProcess "$lKind-imports" llvm-readobj.exe @('--coff-imports',"$lBundle/$lExe")
    Assert-PackageTest ($lImports -notmatch 'pluginleft.dll|pluginbase.dll' -and $lImports -match 'democontracts.dll') 'Plugin imported at startup'
    Add-TestResult "$lKind-genuinely-late" @{}
    $lRelocated="$script:TestOutput/runtime only $lKind"
    Copy-TestImages $lBundle $lRelocated
    $null=Invoke-TestProcess "$lKind-relocated" "$lRelocated/$lExe" @("$lRelocated/result.log") 0 '' $lRelocated
    Assert-PackageTest ((Get-Content "$lRelocated/result.log" -Raw).Replace("`r",'').Trim() -ceq "PASS late $lKind`nCBLRlrbBLlb") 'Relocated late lifecycle mismatch'
    Add-TestResult "$lKind-relocated-lifecycle" @{}
    foreach($lMismatch in @('abi','sdk','dependency')){
        $lRejected="$script:TestOutput/startup-$lKind-$lMismatch"
        Copy-TestImages $lBundle $lRejected
        Set-TestIdentityMismatch "$lRejected/democontracts.dll" $lMismatch
        $null=Invoke-TestProcess "startup-$lKind-$lMismatch" "$lRejected/$lExe" @("$lRejected/result.log") 217 'Package startup failed: EPackageError:' $lRejected
        Assert-PackageTest (-not(Test-Path "$lRejected/result.log")) 'Rejected startup ran program body'
    }
}
$lFixtures="$script:TestOutput/fixtures"; $lDistribution="$script:TestOutput/negative-packages"
New-Item -ItemType Directory -Force $lFixtures,$lDistribution | Out-Null
function Compile([string]$Name,[string]$Source,[string]$Kind='Package',[string[]]$Requires=@(),[int]$Expected=0,[string]$Contains=''){
    $p=@{SdkRoot=$SdkRoot; Source=$Source; Kind=$Kind; SmartLink=[bool]$SmartLink
        OutputDirectory=$(if($Kind -eq 'Package'){$lDistribution}else{"$script:TestOutput/$Name"})
        PackagePath=@($lProviders,$lDistribution)}
    if($Requires.Count){$p.RequiredPackages=$Requires}
    $null=Invoke-TestScript "build-$Name" "$lRoot/scripts/Invoke-NexusFPCPackageCompile.ps1" $p $Expected $Contains
}
function Package([string]$Name,[Collections.IDictionary]$Units,[string]$Requires='nxrtl, democontracts'){
    $lDirectory="$lFixtures/$Name"
    foreach($lUnit in $Units.Keys){Write-TestFile "$lDirectory/$lUnit.pas" $Units[$lUnit]}
    Write-TestFile "$lDirectory/$Name.nxpk" ("package $Name; requires $Requires; contains "+($Units.Keys -join ',')+'; end.')
    Compile $Name "$lDirectory/$Name.nxpk"
}
function Unit([string]$Name,[string]$Declarations='',[string]$Initialization='',[string]$Finalization='',[string]$Interface=''){
    return "unit $Name; {`$mode objfpc}{`$H+}`ninterface`nuses SysUtils, Classes, PkgContracts;`n$Interface`nimplementation`n$Declarations`ninitialization`n$Initialization`nfinalization`n$Finalization`nend."
}
$lErrorClass=@'
type ELocalFailure = class(Exception)
  destructor Destroy; override;
end;
destructor ELocalFailure.Destroy;
begin Trace:=Trace+'D'; inherited Destroy; end;
'@
Package failinit ([ordered]@{
    FailFirst=(Unit FailFirst -Initialization "Trace:=Trace+'F';" -Finalization "Trace:=Trace+'f';")
    FailLast=(Unit FailLast ($lErrorClass+'type TFailedClass = class(TPersistent);') "Trace:=Trace+'!'; RegisterClassAlias(TFailedClass,'FailedAlias'); raise ELocalFailure.Create('init-marker');")
})
Package faildependency ([ordered]@{FailDependencyUnit=(Unit FailDependencyUnit $lErrorClass "Trace:=Trace+'!'; raise ELocalFailure.Create('init-marker');")}) 'nxrtl, democontracts, pluginbase'
Package cleanupfail ([ordered]@{
    CleanupFirst=(Unit CleanupFirst -Initialization "Trace:=Trace+'X';" -Finalization "Trace:=Trace+'x'; raise Exception.Create('cleanup-marker');")
    CleanupLast=(Unit CleanupLast $lErrorClass "Trace:=Trace+'!'; raise ELocalFailure.Create('init-marker');")
}) 'nxrtl, democontracts, pluginbase'
Package failfini ([ordered]@{FailFiniUnit=(Unit FailFiniUnit $lErrorClass "Trace:=Trace+'Z';" "Trace:=Trace+'z'; raise ELocalFailure.Create('finalization-marker');")})
Package callbackfail ([ordered]@{CallbackFailUnit=(Unit CallbackFailUnit ($lErrorClass+"procedure FailedCleanup; begin Trace:=Trace+'K'; raise ELocalFailure.Create('callback-marker'); end;") "Trace:=Trace+'Y'; RegisterPackageCleanup(PackageModuleFromAddress(@FailedCleanup),@FailedCleanup);" "Trace:=Trace+'y';")})
Package newtls ([ordered]@{NewTLSUnit=(Unit NewTLSUnit 'threadvar Value: LongInt;' "if Value<>0 then raise Exception.Create('TLS not zero'); Value:=42; Trace:=Trace+'T';" "if Value<>42 then raise Exception.Create('TLS lost before finalization'); Trace:=Trace+'t';")})
Package nestedload ([ordered]@{NestedLoadUnit=(Unit NestedLoadUnit -Initialization "Trace:=Trace+'Q'; LoadPackage('pluginleft.dll');")})
Package nestedunload ([ordered]@{NestedUnloadUnit=(Unit NestedUnloadUnit 'procedure Marker; begin end;' "Trace:=Trace+'U';" "Trace:=Trace+'u'; UnloadPackage(PackageModuleFromAddress(@Marker));")})
Package nonexception ([ordered]@{NonExceptionUnit=(Unit NonExceptionUnit "type TLocalError = class(TObject) destructor Destroy; override; end; destructor TLocalError.Destroy; begin Trace:=Trace+'D'; inherited Destroy; end;" "Trace:=Trace+'N'; raise TLocalError.Create;")})
Compile failure-host "$PSScriptRoot/package_loader_failures.pas" Console @('democontracts')
$lApp=Get-NexusPackageBundle "$script:TestOutput/failure-host"
foreach($lMode in @('init','new-dependency','live-dependency','cleanup','finalization','callback','tls','nested-load','nested-unload','non-exception','missing','not-package','duplicate','sdk','abi','dependency')){
    $lCase="$script:TestOutput/case-$lMode"
    Copy-TestImages $lApp $lCase
    if($lMode -eq 'duplicate'){Copy-Item "$lCase/pluginleft.dll" "$lCase/duplicate.dll"}
    if($lMode -in @('sdk','abi','dependency')){
        if($lMode -eq 'dependency'){$lTarget="$lCase/pluginbase.dll"}
        else{$lTarget="$lCase/bad.dll"; Copy-Item "$lCase/pluginleft.dll" $lTarget}
        Set-TestIdentityMismatch $lTarget $lMode
    }
    $lArguments=@($lMode)
    if($lMode -eq 'not-package'){$lArguments+="$env:WINDIR/System32/version.dll"}
    $null=Invoke-TestProcess "run-$lMode" "$lCase/package_loader_failures.exe" $lArguments 0 "PASS $lMode" $lCase
}
$lCurrent="$lDistribution/current.json"; $lBefore=(Get-FileHash $lCurrent).Hash
$lOriginal=Get-TestHashes (Get-NexusPackageBundle $lDistribution)
function Check-Publication([string]$Name){
    Assert-PackageTest ((Get-FileHash $lCurrent).Hash -ceq $lBefore) 'Failed build changed selected generation'
    Assert-PackageTest ((Get-TestHashes (Get-NexusPackageBundle $lDistribution)) -ceq $lOriginal) 'Failed build changed published artifacts'
    Add-TestResult $Name @{}
}
Write-TestFile "$lFixtures/broken.nxpk" 'package broken; requires nxrtl; contains MissingUnit; end.'
Compile broken "$lFixtures/broken.nxpk" Package @() 1 'Compilation failed'
Check-Publication failed-build-preserves-publication
Write-TestFile "$lFixtures/BrokenLinkUnit.pas" (Unit BrokenLinkUnit "procedure MissingExternal; external name 'MissingPackageLinkSymbol';" 'MissingExternal;')
Write-TestFile "$lFixtures/broken.nxpk" 'package broken; requires nxrtl, democontracts; contains BrokenLinkUnit; end.'
Compile broken-link "$lFixtures/broken.nxpk" Package @() 1 'Compilation failed'
Assert-PackageTest (@(Get-ChildItem "$lDistribution/work-*/compile.log" | Where-Object {[IO.File]::ReadAllText($_.FullName).Contains('MissingPackageLinkSymbol')}).Count -gt 0) 'Expected missing external linker failure'
Check-Publication failed-link-preserves-publication
Compile stale-consumers "$lLate/source/base/pluginbase.nxpk" Package @() 1 'Dependency build mismatch'
Check-Publication stale-consumers-preserve-publication
$lPair="$script:TestOutput/mismatched-pair"; $lPairOutput="$script:TestOutput/pair-output"
New-Item -ItemType Directory -Force $lPair,$lPairOutput | Out-Null
Get-ChildItem (Get-NexusPackageBundle $lDistribution) -File | Where-Object Extension -In '.nxp','.dll' | Copy-Item -Destination $lPair
Set-TestIdentityMismatch "$lPair/failinit.dll" dependency
$lSDKIdentity=(Get-Content "$SdkRoot/sdk.json" -Raw | ConvertFrom-Json).SDKIdentity
$lCode='. '+(ConvertTo-TestLiteral "$lRoot/scripts/NexusFPCPackageArtifacts.ps1")+"`nPublish-NexusPackageBundle -OutputDirectory "+(ConvertTo-TestLiteral $lPairOutput)+' -Work '+(ConvertTo-TestLiteral $lPair)+' -Name failinit -Kind Package -SDKIdentity '+(ConvertTo-TestLiteral $lSDKIdentity)+' -PackageDirectories '+(ConvertTo-TestLiteral $lPair)
$null=Invoke-TestPowerShell reject-mismatched-pair $lCode 1 'metadata/image identity mismatch'
Assert-PackageTest (-not(Test-Path "$lPairOutput/current.json")) 'Mismatched package published'
$lDamaged="$script:TestOutput/damaged-bundle"
Copy-Item $lDistribution $lDamaged -Recurse
$lDLL="$(Get-NexusPackageBundle $lDamaged)/failinit.dll"
[IO.File]::WriteAllBytes($lDLL,[byte[]]([IO.File]::ReadAllBytes($lDLL)+[Text.Encoding]::ASCII.GetBytes('tampered')))
$lCode='. '+(ConvertTo-TestLiteral "$lRoot/scripts/NexusFPCPackageArtifacts.ps1")+"`nGet-NexusPackageBundle "+(ConvertTo-TestLiteral $lDamaged)
$null=Invoke-TestPowerShell reject-damaged-bundle $lCode 1 'differs from its manifest'
Write-Host "PASS package loader suite ($($script:TestSteps.Count) steps)"
