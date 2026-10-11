# Build the first native Win64 compiler from a stock hardware80 bootstrap.
function New-NexusFPCBootstrapSeed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$BootstrapBin,
        [Parameter(Mandatory)][string]$OutputRoot
    )
    $ErrorActionPreference = 'Stop'
    $lBootstrap = Join-Path $BootstrapBin 'ppc386.exe'
    $lMake = Join-Path $BootstrapBin 'make.exe'
    $lBootstrapRTL = [IO.Path]::GetFullPath((Join-Path $BootstrapBin '../../units/i386-win32/rtl'))
    $lSource = Join-Path $OutputRoot 'source'
    $lUnits32 = Join-Path $OutputRoot 'units32'
    $lUnits64 = Join-Path $OutputRoot 'units64'
    $lRTL = Join-Path $OutputRoot 'rtl64'
    $lBin = Join-Path $OutputRoot 'bin'
    $lLogs = Join-Path $OutputRoot 'logs'
    foreach ($lDirectory in @($lSource,$lUnits32,$lUnits64,$lRTL,$lBin,$lLogs)) {
        New-Item -ItemType Directory -Force -Path $lDirectory | Out-Null
    }
    function Invoke-SeedStep([string]$AName,[string]$AProgram,[string[]]$AArguments) {
        $lLog = Join-Path $lLogs ($AName + '.log')
        $ErrorActionPreference = 'Continue'
        & $AProgram @AArguments *> $lLog
        $lCode = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($lCode -ne 0) {
            Get-Content -LiteralPath $lLog -Tail 15 | Write-Host
            throw "$AName failed ($lCode). See $lLog"
        }
        Write-Host "PASS $AName"
    }
    $lCompilerSource = Join-Path $SourceRoot 'compiler'
    # Compiler and RTL share the current integer Currency parser. Stock 3.2.2
    # Currency Val fails to report some endpoint overflows.
    $lRTLIncludes = Join-Path $OutputRoot 'rtl/inc'
    New-Item -ItemType Directory -Force -Path $lRTLIncludes | Out-Null
    Copy-Item -LiteralPath "$SourceRoot/rtl/inc/currval.inc" -Destination $lRTLIncludes
    foreach ($lFile in Get-ChildItem -LiteralPath $lCompilerSource -Recurse -File) {
        if ($lFile.Extension -notin @('.pas','.pp','.inc') -or
            $lFile.Name -in @('msgtxt.inc','msgidx.inc')) { continue }
        $lDestination = Join-Path $lSource $lFile.FullName.Substring($lCompilerSource.Length+1)
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $lDestination) | Out-Null
        Copy-Item -LiteralPath $lFile.FullName -Destination $lDestination
    }
    $lOptions = @('-n',"-Fu$lBootstrapRTL","-FU$lUnits32","-FE$lBin")
    Invoke-SeedStep 'message-generator' $lBootstrap ($lOptions + @("$lSource/utils/msg2inc.pp"))
    Invoke-SeedStep 'messages' "$lBin/msg2inc.exe" @("$SourceRoot/compiler/msg/errore.msg","$lSource/msg",'msg')
    $lCompilerOptions = @('-O2','-dx86_64')
    foreach ($lPart in @('','x86_64','x86','systems')) {
        $lDirectory = Join-Path $lSource $lPart
        $lCompilerOptions += @("-Fu$lDirectory","-Fi$lDirectory")
    }
    Invoke-SeedStep 'compiler32' $lBootstrap ($lOptions + $lCompilerOptions + @('-oseed32.exe',"$lSource/pp.pas"))
    $lOldPath = $env:PATH
    try {
        $env:PATH = "$BootstrapBin;$lOldPath"
        Invoke-SeedStep 'rtl64' $lMake @('-s','-C',"$SourceRoot/rtl/win64",'all',
            "FPC=$($lBin.Replace('\','/'))/seed32.exe",'CPU_TARGET=x86_64','OS_TARGET=win64',
            'BINUTILSPREFIX=','CROSSBINDIR=',
            "COMPILER_UNITTARGETDIR=$($lRTL.Replace('\','/'))",
            "COMPILER_TARGETDIR=$($lBin.Replace('\','/'))",
            "FPCMADE=$($OutputRoot.Replace('\','/'))/rtl.fpcmade",'OPT=-n -XP')
        $lOptions = @('-n','-B','-Twin64','-XP',"-Fu$lRTL","-FU$lUnits64","-FE$lBin")
        Invoke-SeedStep 'compiler64' "$lBin/seed32.exe" ($lOptions + $lCompilerOptions + @('-oppcx64.exe',"$lSource/pp.pas"))
    } finally { $env:PATH = $lOldPath }
    [pscustomobject]@{ Compiler = "$lBin/ppcx64.exe"; RTL = $lRTL; Logs = $lLogs }
}
