# Copyright (c) 2026 Kevin Collins. SPDX-License-Identifier: GPL-2.0-or-later
# Shared process/logging helpers. Every DLL probe runs in its own native process.
function Initialize-PackageTests([string]$Directory) {
    $script:TestOutput = [IO.Path]::GetFullPath($Directory)
    if ((Test-Path $script:TestOutput) -and (Get-ChildItem $script:TestOutput -Force)) {
        throw "Output directory must be empty: $script:TestOutput"
    }
    New-Item -ItemType Directory -Force $script:TestOutput | Out-Null
    $script:TestSteps = [Collections.Generic.List[object]]::new()
}
function Assert-PackageTest([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Write-TestFile([string]$Path,[string]$Content) {
    New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
    [IO.File]::WriteAllText($Path,$Content,[Text.UTF8Encoding]::new($false))
}
function Add-TestResult([string]$Name,$Details) {
    $script:TestSteps.Add([pscustomobject]@{ Name=$Name; Details=$Details })
    $script:TestSteps | ConvertTo-Json -Depth 8 | Set-Content "$script:TestOutput/steps.json" -Encoding UTF8
    Write-Host "PASS $Name"
}
function Invoke-TestProcess {
    param([string]$Name,[string]$Program,[string[]]$Arguments=@(),[int]$Expected=0,
          [string]$Contains='', [string]$Directory=$script:TestOutput)
    $lLog = "$script:TestOutput/$Name.log"
    Push-Location $Directory
    try {
        $ErrorActionPreference = 'Continue'
        # A pipeline makes Windows PowerShell wait for GUI subsystem images too.
        & $Program @Arguments 2>&1 | Out-File -LiteralPath $lLog -Encoding UTF8
        $lCode = $LASTEXITCODE
    } finally { Pop-Location }
    $ErrorActionPreference = 'Stop'
    $lText = [IO.File]::ReadAllText($lLog)
    $lDetails = @{ Program=$Program; Arguments=$Arguments; Directory=$Directory; ExitCode=$lCode; Expected=$Expected; Log=$lLog }
    if ($lCode -ne $Expected -or ($Contains -and -not $lText.Contains($Contains))) {
        $script:TestSteps.Add([pscustomobject]@{ Name=$Name; Details=$lDetails; Failed=$true })
        $script:TestSteps | ConvertTo-Json -Depth 8 | Set-Content "$script:TestOutput/steps.json" -Encoding UTF8
        throw "$Name failed: exit $lCode, expected $Expected, text '$Contains'. See $lLog`n$($lText.Substring([Math]::Max(0,$lText.Length-4000)))"
    }
    Add-TestResult $Name $lDetails
    return $lText
}
function ConvertTo-TestLiteral($Value) {
    if ($Value -is [bool]) { if ($Value) { return '$true' } else { return '$false' } }
    if ($Value -is [array]) { return '@('+(($Value | ForEach-Object { ConvertTo-TestLiteral $_ }) -join ',')+')' }
    return "'"+([string]$Value).Replace("'","''")+"'"
}
function Invoke-TestPowerShell([string]$Name,[string]$Code,[int]$Expected=0,[string]$Contains='') {
    $lScript = "$script:TestOutput/$Name.ps1"
    Write-TestFile $lScript ("`$ErrorActionPreference='Stop'`ntry {`n"+$Code+"`n} catch { Write-Output `$_.Exception.Message; Write-Output `$_.ScriptStackTrace; exit 1 }`n")
    Invoke-TestProcess $Name powershell.exe @('-NoProfile','-ExecutionPolicy','Bypass','-File',$lScript) $Expected $Contains
}
function Invoke-TestScript([string]$Name,[string]$Path,[hashtable]$Parameters,[int]$Expected=0,[string]$Contains='') {
    $lCode = '& '+(ConvertTo-TestLiteral $Path)
    foreach ($lKey in ($Parameters.Keys | Sort-Object)) {
        $lCode += ' -'+$lKey+':'+(ConvertTo-TestLiteral $Parameters[$lKey])
    }
    Invoke-TestPowerShell $Name $lCode $Expected $Contains
}
function Get-TestHashes([string]$Directory) {
    $lRoot = (Resolve-Path -LiteralPath $Directory).Path
    return ((Get-ChildItem -LiteralPath $lRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
        $_.FullName.Substring($lRoot.Length)+':'+(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }) -join "`n")
}
function Move-TestArtifact([string]$Source,[string]$Destination) {
    $lSource = [IO.Path]::GetFullPath($Source)
    $lDestination = [IO.Path]::GetFullPath($Destination)
    $lPrefix = $script:TestOutput.TrimEnd('\')+'\'
    foreach ($lPath in @($lSource,$lDestination)) {
        if (-not $lPath.StartsWith($lPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw "Move outside test output: $lPath" }
    }
    Move-Item -LiteralPath $lSource -Destination $lDestination
}
function Copy-TestImages([string]$Source,[string]$Destination) {
    New-Item -ItemType Directory -Force $Destination | Out-Null
    Get-ChildItem -LiteralPath $Source -File | Where-Object Extension -In '.nxpl','.dll','.exe' |
        Copy-Item -Destination $Destination
}
function Get-TestUnitHash([string]$Directory,[string]$Unit) {
    return ((@('.nxu','.o') | ForEach-Object { (Get-FileHash -LiteralPath "$Directory/$Unit$_").Hash }) -join ':')
}
function Hide-TestUnit([string]$Directory,[string]$Unit) {
    foreach ($lSuffix in @('.pas','.nxu','.o')) {
        $lPath = "$Directory/$Unit$lSuffix"
        if (Test-Path -LiteralPath $lPath) { Move-TestArtifact $lPath "$lPath.hidden" }
    }
}
function Get-TestCompilerOptions([string]$Sdk,[string]$Directory,[bool]$Smart=$false) {
    $lOptions = @('-n','-Mobjfpc',"-Fu$Sdk/work/rtl-units","-FU$Directory","-FE$Directory",
        "-FD$((Get-Command llvm-readobj.exe).Source | Split-Path)")
    if ($Smart) { $lOptions += '-CX','-XX' }
    return $lOptions
}
function Get-TestDescriptorOffsets([byte[]]$Data) {
    # Independent PE reader used only to corrupt specific fields in negative tests.
    $lPE = [BitConverter]::ToUInt32($Data,0x3c)
    $lCount = [BitConverter]::ToUInt16($Data,$lPE+6)
    $lOptSize = [BitConverter]::ToUInt16($Data,$lPE+20)
    $lOpt = $lPE+24
    Assert-PackageTest ([BitConverter]::ToUInt16($Data,$lOpt) -eq 0x20b) 'Expected PE32+'
    $lBase = [BitConverter]::ToUInt64($Data,$lOpt+24)
    function Offset([uint64]$Rva) {
        for ($i=0; $i -lt $lCount; $i++) {
            $p=$lOpt+$lOptSize+40*$i+8
            $v=[BitConverter]::ToUInt32($Data,$p); $a=[BitConverter]::ToUInt32($Data,$p+4)
            $s=[BitConverter]::ToUInt32($Data,$p+8); $r=[BitConverter]::ToUInt32($Data,$p+12)
            if ($a -le $Rva -and $Rva -lt $a+[Math]::Max($v,$s)) { return [int]($r+$Rva-$a) }
        }
        throw "Unmapped RVA $Rva"
    }
    $e=Offset ([BitConverter]::ToUInt32($Data,$lOpt+112))
    $n=[BitConverter]::ToUInt32($Data,$e+24)
    $f=Offset ([BitConverter]::ToUInt32($Data,$e+28))
    $names=Offset ([BitConverter]::ToUInt32($Data,$e+32))
    $ord=Offset ([BitConverter]::ToUInt32($Data,$e+36))
    for ($i=0; $i -lt $n; $i++) {
        $p=Offset ([BitConverter]::ToUInt32($Data,$names+4*$i)); $end=$p
        while ($Data[$end] -ne 0) { $end++ }
        if ([Text.Encoding]::ASCII.GetString($Data,$p,$end-$p) -eq 'FPC_PACKAGE_INFO') {
            $o=[BitConverter]::ToUInt16($Data,$ord+2*$i)
            $p=Offset ([BitConverter]::ToUInt32($Data,$f+4*$o))
            $d=Offset ([BitConverter]::ToUInt64($Data,$p)-$lBase)
            return @{ Descriptor=$d; SDK=(Offset ([BitConverter]::ToUInt64($Data,$d+18*8)-$lBase)); Build=(Offset ([BitConverter]::ToUInt64($Data,$d+19*8)-$lBase)) }
        }
    }
    throw 'Missing stable package descriptor export'
}
function Set-TestIdentityMismatch([string]$Path,[string]$Kind) {
    $lBytes=[IO.File]::ReadAllBytes($Path); $lOffsets=Get-TestDescriptorOffsets $lBytes
    if ($Kind -eq 'abi') { [BitConverter]::GetBytes([uint64]999).CopyTo($lBytes,$lOffsets.Descriptor+8) }
    else {
        $lOffset=if ($Kind -eq 'sdk') { $lOffsets.SDK } else { $lOffsets.Build }
        for ($i=1; $i -le $lBytes[$lOffset]; $i++) { $lBytes[$lOffset+$i]=[byte][char]'E' }
    }
    [IO.File]::WriteAllBytes($Path,$lBytes)
}
