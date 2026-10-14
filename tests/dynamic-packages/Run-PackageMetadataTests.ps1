# Copyright (c) 2026 Kevin Collins. SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([Parameter(Mandatory)][string]$SdkRoot,[Parameter(Mandatory)][string]$OutputRoot)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/PackageTestCommon.ps1"
Initialize-PackageTests $OutputRoot
$SdkRoot=(Resolve-Path $SdkRoot).Path
$lCompiler="$SdkRoot/bin/ppcx64.exe"; $lBuild="$script:TestOutput/driver"; $lFixtures="$script:TestOutput/fixtures"
New-Item -ItemType Directory -Force $lBuild,$lFixtures | Out-Null
$lOptions=(Get-TestCompilerOptions $SdkRoot $lBuild)+@('-B','-O1','-dx86_64')
foreach($lPart in @('','x86_64','x86','systems')){
    $lOptions+="-Fu$SdkRoot/work/seed/source/$lPart","-Fi$SdkRoot/work/seed/source/$lPart"
}
$null=Invoke-TestProcess 'build-driver' $lCompiler ($lOptions+@("$PSScriptRoot/package_metadata_test.pas"))
$lDriver="$lBuild/package_metadata_test.exe"
$null=Invoke-TestProcess 'names' $lDriver @('names',$lFixtures) 0 'PASS names'
$null=Invoke-TestProcess 'disabled-path' $lDriver @('disabled',$lFixtures,'DoesNotExist') 0 'PASS graph 1'
$lCommon=Get-TestCompilerOptions $SdkRoot $lFixtures
Write-TestFile "$lFixtures/ux.pas" 'unit ux; interface function Marker: LongInt; implementation function Marker: LongInt; begin Result:=37; end; end.'
$null=Invoke-TestProcess 'compile-unit' $lCompiler ($lCommon+@("$lFixtures/ux.pas"))
$lOriginalHash=(Get-FileHash "$lFixtures/ux.nxu").Hash
$null=Invoke-TestProcess 'write-roundtrip' $lDriver @('write',$lFixtures,"$lFixtures/ux.nxu")
Assert-PackageTest ($lOriginalHash -eq (Get-FileHash "$lFixtures/ux.nxu").Hash) 'Writer changed original PPU'
$null=Invoke-TestProcess 'read-roundtrip' $lDriver @('read',$lFixtures,'Fixture') 0 'PASS read 1'
$lSeed=[IO.File]::ReadAllBytes("$lFixtures/Fixture.nxp")
function Entries([byte[]]$Data) {
    $p=32; $end=32+[BitConverter]::ToUInt32($Data,16); $result=@{}
    while($p -lt $end){
        $s=[BitConverter]::ToInt32($Data,$p)
        Assert-PackageTest ($s -ge 0 -and $Data[$p+4] -eq 1) 'Invalid entry in generated metadata'
        $result[[int]$Data[$p+5]]=@($p,($p+6),$s); $p+=6+$s
    }
    Assert-PackageTest ($p -eq $end) 'Metadata size mismatch'
    return $result
}
$lTable=(Entries $lSeed)[243][1]
$lOffset=[BitConverter]::ToInt32($lSeed,$lTable); $lSize=[BitConverter]::ToInt32($lSeed,$lTable+4)
$lEmbedded=[byte[]]$lSeed[$lOffset..($lOffset+$lSize-1)]
Assert-PackageTest ([Text.Encoding]::ASCII.GetString($lSeed,0,6) -ceq 'NXP004') 'Wrong PCP signature'
Assert-PackageTest ([Text.Encoding]::ASCII.GetString($lEmbedded,0,6) -ceq 'NXU208') 'Wrong embedded signature'
function ShortBytes([string]$Value){
    $b=[Text.Encoding]::ASCII.GetBytes($Value)
    Assert-PackageTest ($b.Length -le 255) 'Oversized shortstring'
    return ,([byte[]](@([byte]$b.Length)+$b))
}
function IntBytes([int]$Value,[bool]$Big=$false){
    $b=[BitConverter]::GetBytes($Value); if($Big){[array]::Reverse($b)}; return ,$b
}
function Fixture([string]$Name,[string[]]$Requires=@(),[string[]]$Units=@(),[bool]$Big=$false){
    $lRequired=[Collections.Generic.List[byte]]::new(); $lContained=[Collections.Generic.List[byte]]::new()
    foreach($n in $Requires){$lRequired.AddRange((ShortBytes $n)); $lRequired.AddRange((ShortBytes ('A'*32)))}
    foreach($n in $Units){$lContained.AddRange((ShortBytes $n)); $lContained.AddRange((ShortBytes "$n.nxu"))}
    $lPayloads=[ordered]@{
        93=(ShortBytes $Name); 92=[byte[]]((ShortBytes "$Name.dll")+(ShortBytes '')+(ShortBytes ('A'*32)))
        244=(IntBytes $Requires.Count $Big); 245=$lRequired.ToArray()
        246=(IntBytes $Units.Count $Big); 247=$lContained.ToArray()
    }
    $lBody=[Collections.Generic.List[byte]]::new(); [uint32]$lCRC=[uint32]::MaxValue
    [uint32]$lPolynomial=[Convert]::ToUInt32('EDB88320',16)
    foreach($lEntry in $lPayloads.GetEnumerator()){
        $n=$lEntry.Key; [byte[]]$b=$lEntry.Value
        $lBody.AddRange((IntBytes $b.Length $Big)); $lBody.Add(1); $lBody.Add([byte]$n); $lBody.AddRange($b)
        foreach($v in $b){
            $lCRC=$lCRC -bxor [uint32]$v
            for($i=0;$i -lt 8;$i++){if($lCRC -band 1){$lCRC=($lCRC -shr 1) -bxor $lPolynomial}else{$lCRC=$lCRC -shr 1}}
        }
    }
    $lCRC=$lCRC -bxor [uint32]::MaxValue
    $lTableStart=32+$lBody.Count+6
    $lBody.AddRange((IntBytes ($Units.Count*8) $Big)); $lBody.Add(1); $lBody.Add(243)
    $lBody.AddRange([byte[]]::new($Units.Count*8))
    $lBody.AddRange((IntBytes 0 $Big)); $lBody.Add(1); $lBody.Add(255)
    $lData=[Collections.Generic.List[byte]]::new()
    $lData.AddRange([byte[]]$lSeed[0..11])
    $lData.AddRange((IntBytes $(if($Big){4}else{4096})))
    $lData.AddRange((IntBytes $lBody.Count)); $lData.AddRange([BitConverter]::GetBytes($lCRC))
    $lData.AddRange((IntBytes $Requires.Count)); $lData.AddRange((IntBytes $Units.Count)); $lData.AddRange($lBody.ToArray())
    for($i=0;$i -lt $Units.Count;$i++){
        $lData.AddRange([byte[]]::new(16-$lData.Count%16)); $lStart=$lData.Count; $lData.AddRange($lEmbedded)
        $b=[byte[]]((IntBytes $lStart $Big)+(IntBytes $lEmbedded.Length $Big))
        for($j=0;$j -lt 8;$j++){$lData[$lTableStart+$i*8+$j]=$b[$j]}
    }
    $lData.AddRange([byte[]]::new(16-$lData.Count%16)); return ,$lData.ToArray()
}
function Save([string]$Name,[string[]]$Requires=@(),[string[]]$Units=@()){
    [IO.File]::WriteAllBytes("$lFixtures/$Name.nxp",(Fixture $Name $Requires $Units))
}
function Read-Case([string]$Label,[byte[]]$Data,[int]$Expected=0,[string]$Contains='PASS read'){
    [IO.File]::WriteAllBytes("$lFixtures/Case.nxp",$Data)
    $null=Invoke-TestProcess $Label $lDriver @('read',$lFixtures,'Case') $Expected $Contains
}
function Reject([string]$Label,[byte[]]$Data,[string]$Contains='Invalid PCP file'){Read-Case $Label $Data 1 $Contains}
function Mutate([byte[]]$Data,[int]$Offset,[string]$Format,$Value){
    $b=$Data.Clone()
    $v=switch($Format){B{,[byte[]]@([byte]$Value)} H{,[BitConverter]::GetBytes([uint16]$Value)} U{,[BitConverter]::GetBytes([uint32]$Value)} I{,[BitConverter]::GetBytes([int]$Value)}}
    $v.CopyTo($b,$Offset); return ,$b
}
Read-Case 'independent-empty-v4' (Fixture Case)
Read-Case 'independent-two-units-v4' (Fixture Case @() @('UX','UY'))
Read-Case 'opposite-endian-metadata-v4' (Fixture Case @() @('UX') $true)
Read-Case 'metadata-over-buffer-boundary' (Fixture Case @(0..1599 | ForEach-Object {'Required{0:D4}' -f $_}))
Save D @() @('UX'); Save B @('D'); Save C @('d'); Save A @('B','C')
$null=Invoke-TestProcess diamond $lDriver @('graph',$lFixtures,'A') 0 'PASS graph 4'
Save A @('a')
$null=Invoke-TestProcess self-cycle $lDriver @('graph',$lFixtures,'A') 1 'Circular package dependency: A -> A'
Save A @('B'); Save B @('C'); Save C @('a')
$null=Invoke-TestProcess indirect-cycle $lDriver @('graph',$lFixtures,'A') 1 'Circular package dependency: A -> B -> C -> A'
$null=Invoke-TestProcess building-self-without-pcp $lDriver @('building',$lFixtures,'Root','root') 1 'Circular package dependency: Root -> root'
Save B @('Root')
$null=Invoke-TestProcess building-indirect-without-pcp $lDriver @('building',$lFixtures,'Root','B') 1 'Circular package dependency: Root -> B -> Root'
Save B @() @('UX'); Save C @() @('ux'); Save A @('B','C')
$null=Invoke-TestProcess duplicate-owner $lDriver @('graph',$lFixtures,'A') 1 'Unit UX is contained in both packages B and C'
Save A @('C','B')
$null=Invoke-TestProcess duplicate-owner-reversed $lDriver @('graph',$lFixtures,'A') 1 'Unit UX is contained in both packages C and B'
$lBase=Fixture Case @() @('UX','UY'); $lOffsets=Entries $lBase
$b=$lBase.Clone(); [Text.Encoding]::ASCII.GetBytes('PCP').CopyTo($b,0)
Reject foreign-package-same-version $b 'expected NXP signature'
foreach($n in @(0,1,6,19,31)){
    $b=[byte[]]::new($n); [array]::Copy($lBase,$b,$n); Reject "short-header-$n" $b "Can't find package"
}
foreach($c in @(
    @('bad-magic',0,'B',0),@('bad-version',3,'B',57),@('wrong-cpu',8,'H',65535),@('wrong-target',10,'H',65535),
    @('both-endian-flags',12,'U',4100),@('missing-endian-flags',12,'U',0),@('oversized-metadata',16,'U',[uint32]::MaxValue),@('negative-header-count',24,'I',-1))){
    Reject $c[0] (Mutate $lBase $c[1] $c[2] $c[3]) "Can't find package"
}
foreach($n in $lOffsets.Keys){Reject "truncated-entry-$n" ([byte[]]$lBase[0..($lOffsets[$n][0]+2)]) "Can't find package"}
foreach($c in @(
    @('negative-entry-size',$lOffsets[93][0],'I',-1),@('huge-entry-size',$lOffsets[93][0],'I',0x7fffffff),
    @('wrong-entry-id',($lOffsets[93][0]+4),'B',2),@('wrong-entry-number',($lOffsets[93][0]+5),'B',92),
    @('truncated-string',$lOffsets[93][1],'B',255),@('negative-required-count',$lOffsets[244][1],'I',-1),
    @('required-count-mismatch',$lOffsets[244][1],'I',2),@('unit-count-mismatch',$lOffsets[246][1],'I',1),
    @('bad-table-size',$lOffsets[243][0],'I',8),@('bad-checksum',20,'U',0),
    @('offset-in-metadata',$lOffsets[243][1],'I',0),@('negative-offset',$lOffsets[243][1],'I',-1),
    @('offset-past-eof',$lOffsets[243][1],'I',0x7fffffff),@('size-past-eof',($lOffsets[243][1]+4),'I',0x7fffffff),
    @('negative-ppu-size',($lOffsets[243][1]+4),'I',-1),@('short-ppu-header',($lOffsets[243][1]+4),'I',12),
    @('overlapping-ppus',($lOffsets[243][1]+8),'I',([BitConverter]::ToInt32($lBase,$lOffsets[243][1]))))){
    Reject $c[0] (Mutate $lBase $c[1] $c[2] $c[3])
}
Reject renamed-package (Fixture Other)
Reject duplicate-required-names (Fixture Case @('Dep','dep'))
Reject duplicate-contained-names (Fixture Case @() @('UX','ux'))
Reject empty-required-name (Fixture Case @(''))
Reject empty-contained-name (Fixture Case @() @(''))
$lFirst=[BitConverter]::ToInt32($lBase,$lOffsets[243][1])
$b=$lBase.Clone(); [Text.Encoding]::ASCII.GetBytes('PPU').CopyTo($b,$lFirst)
Reject foreign-embedded-unit-same-version $b 'requires NexusFPC NXU signature'
foreach($c in @(@('ppu-magic',0,'B',0),@('ppu-version',3,'B',57),@('ppu-cpu',8,'H',65535),@('ppu-target',10,'H',65535),@('ppu-size',16,'U',[uint32]::MaxValue))){
    Reject $c[0] (Mutate $lBase ($lFirst+$c[1]) $c[2] $c[3])
}
Reject truncated-embedded-ppu ([byte[]]$lBase[0..($lFirst+39)])
Hide-TestUnit $lFixtures ux
Write-TestFile "$lFixtures/consumer.pas" 'program consumer; uses ux; begin if Marker<>37 then Halt(1); end.'
Write-TestFile "$lFixtures/consumer.rsp" (($lCommon+@('-Cn','-FPFixture',"-Fp$lFixtures")) -join "`n")
$null=Invoke-TestProcess source-free-pcp-consumption $lDriver @('consume','-n @consumer.rsp consumer.pas') 0 '' $lFixtures
Assert-PackageTest (-not(Test-Path "$lFixtures/ux.nxu") -and -not(Test-Path "$lFixtures/ux.o")) 'Standalone artifacts leaked'
Write-TestFile "$lFixtures/conflict.nxpk" 'package conflict; requires Fixture; contains ux; end.'
$null=Invoke-TestProcess contains-required-unit $lDriver @('consume','-n @consumer.rsp conflict.nxpk') 1 'is already contained in package Fixture' $lFixtures
Write-TestFile "$lFixtures/standardunit.pas" 'unit standardunit; interface const Value=37; implementation end.'
Write-TestFile "$lFixtures/supported.nxpk" 'package supported; {$ifndef FPC_HAS_DYNAMIC_PACKAGES}{$fatal Missing package support}{$endif} contains standardunit; end.'
$null=Invoke-TestProcess standard-compiler-package $lCompiler ($lCommon+@('-Cn',"$lFixtures/supported.nxpk"))
Assert-PackageTest ([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes("$lFixtures/supported.nxp"),0,6) -ceq 'NXP004') 'Standard compiler PCP signature'
Write-Host "PASS package metadata suite ($($script:TestSteps.Count) steps)"
