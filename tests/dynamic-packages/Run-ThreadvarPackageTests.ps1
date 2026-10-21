# Copyright (c) 2026 Kevin Collins. SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([Parameter(Mandatory)][string]$SdkRoot,[Parameter(Mandatory)][string]$OutputRoot,[switch]$SmartLink)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/PackageTestCommon.ps1"
Initialize-PackageTests $OutputRoot
$lRoot=(Resolve-Path "$PSScriptRoot/../..").Path
$SdkRoot=(Resolve-Path $SdkRoot).Path
. "$lRoot/tests/dynamic-packages/NXPCPackageArtifacts.ps1"
$lSource="$script:TestOutput/source"; $lPackages="$script:TestOutput/packages"; $lHost="$script:TestOutput/host"
New-Item -ItemType Directory -Force $lSource,$lPackages,$lHost | Out-Null
function Compile([string]$Name,[string]$Source,[string[]]$Requires=@(),[bool]$Program=$false){
    $p=@{SdkRoot=$SdkRoot; Source=$Source; OutputDirectory=$(if($Program){$lHost}else{$lPackages});
        Kind=$(if($Program){'Console'}else{'Package'}); PackagePath=$lPackages; SmartLink=[bool]$SmartLink}
    if($Requires.Count){$p.RequiredPackages=$Requires}
    $null=Invoke-TestScript $Name "$lRoot/tests/dynamic-packages/Invoke-NXPCPackageCompile.ps1" $p
}
Copy-Item "$PSScriptRoot/threadvar_contracts.pas" $lSource
Write-TestFile "$lSource/tvcontracts.nxpk" 'package tvcontracts; requires nxrtl; contains Threadvar_Contracts; end.'
Compile contracts "$lSource/tvcontracts.nxpk"
$lTemplate=Get-Content "$PSScriptRoot/threadvar_provider.pas.in" -Raw
for($i=0;$i -lt 26;$i++){
    $lName="tv$i"; $lUnit="Threadvar_Provider_$i"
    Write-TestFile "$lSource/$($lUnit.ToLowerInvariant()).pas" $lTemplate.Replace('@INDEX@',[string]$i)
    if($i -eq 25){
        $lName='tvfail'; $lUnit+=', Threadvar_Failure'
        Write-TestFile "$lSource/threadvar_failure.pas" "unit Threadvar_Failure; {`$mode objfpc} interface implementation uses SysUtils, Threadvar_Provider_25; threadvar Value: LongInt; initialization if Value<>0 then Halt(91); Value:=18; raise Exception.Create('threadvar-init-failure'); end."
    }
    Write-TestFile "$lSource/$lName.nxpk" "package $lName; requires nxrtl, tvcontracts; contains $lUnit; end."
    Compile $lName "$lSource/$lName.nxpk"
}
Compile host "$PSScriptRoot/threadvar_package_host.pas" @('tvcontracts','tv24') $true
$lBundle=Get-NexusPackageBundle $lHost
Copy-Item "$(Get-NexusPackageBundle $lPackages)/*.dll" $lBundle
$null=Invoke-TestProcess runtime "$lBundle/threadvar_package_host.exe" @() 0 'PASS unified package threadvars' $lBundle
Write-Host 'PASS sequential package threadvar suite'
