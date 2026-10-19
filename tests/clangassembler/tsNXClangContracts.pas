unit tsNXClangContracts;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterClangContractTests(ARegistry: TNXTestRegistry);
implementation
uses
  SysUtils, obNXTestContext, GlobType, Globals, Systems, Triplet, Link,
  I_Linux, T_Linux, I_Win,
  {$ifndef TEST_I386}I_Android, I_Darwin, T_Darwin,{$endif}
  {$ifdef TEST_AARCH64}AGCPUGAS{$else}AGX86ATT{$endif};
type
  TTargetCase = record
    Name: string;
    Info: TSystemInfo;
    LinkerProgram: string;
  end;
var Targets: array of TTargetCase;

function TargetFor(AContext: TNXTestContext): TTargetCase;
var lIndex: Integer; lId: string;
begin
  lId := Copy(AContext.Result.TestId, LastDelimiter('.', AContext.Result.TestId) + 1, MaxInt);
  for lIndex := 0 to High(Targets) do
    if Targets[lIndex].Name = lId then Exit(Targets[lIndex]);
  raise Exception.Create('Unregistered target ' + lId);
end;

procedure AssemblerRegistration(AContext: TNXTestContext);
var lTarget: TTargetCase; lExpected: TAsm; lExternal: Boolean;
begin
  lTarget := TargetFor(AContext);
  TargetInfo := lTarget.Info;
  if TargetInfo.System in Systems_Darwin then lExpected := As_Clang_AsDarwin
  else lExpected := As_Clang_Gas;
  for lExternal := False to True do
  begin
    if lExternal then
      AContext.AssertTrue(SetTargetAsm(TargetInfo.AssemExtern), 'External assembler is registered')
    else AContext.AssertTrue(SetTargetAsm(TargetInfo.Assem), 'Default assembler is registered');
    AContext.AssertTrue(TargetAsm.Id = lExpected, 'Correct target assembler');
    AContext.AssertTrue(TargetAsm.AsmBin = 'clang', 'Clang executable');
    AContext.AssertTrue(AF_LLVM in TargetAsm.Flags, 'LLVM assembler flag');
    AContext.AssertTrue(TargetTriplet(Triplet_LLVM) <> '', 'Nonempty LLVM target triple');
  end;
end;

procedure CheckLinker(AContext: TNXTestContext; const AProgram: string);
var lInstance: TExternalLinker;
begin
  InitLinker;
  try
    AContext.AssertTrue(Linker is TExternalLinker, 'External linker implementation');
    lInstance := TExternalLinker(Linker);
    AContext.AssertTrue(Pos(AProgram + ' ', lInstance.Info.ExeCmd[1]) = 1, 'Executable linker command: ' + AProgram);
    AContext.AssertTrue(Pos(AProgram + ' ', lInstance.Info.DllCmd[1]) = 1, 'Shared-library linker command: ' + AProgram);
  finally DoneLinker; end;
end;

procedure LinkerDefaults(AContext: TNXTestContext);
var lTarget: TTargetCase;
begin
  lTarget := TargetFor(AContext);
  CurrentSettings := Default_Settings;
  AContext.AssertTrue(CS_Link_LLD in CurrentSettings.GlobalSwitches, 'LLD enabled by default');
  TargetInfo := lTarget.Info;
  DontLinkStdlibPath := True;
  CheckLinker(AContext, lTarget.LinkerProgram);
  Exclude(CurrentSettings.GlobalSwitches, CS_Link_LLD);
  CheckLinker(AContext, 'ld');
end;

procedure ArchiveRegistration(AContext: TNXTestContext);
var lKind: TAr;
begin
  AContext.AssertTrue(Assigned(ArInfos[Ar_GNU_Ar]), 'GNU archive driver');
  AContext.AssertTrue(Assigned(ArInfos[Ar_GNU_Ar_Scripted]), 'Scripted GNU archive driver');
  for lKind := Low(TAr) to High(TAr) do
    if Assigned(ArInfos[lKind]) then
      AContext.AssertTrue(Pos('sdar', ArInfos[lKind]^.ArCmd) = 0, 'Retired SDCC archive command');
end;

procedure RegisterClangContractTests(ARegistry: TNXTestRegistry);
  procedure AddTarget(const AName: string; const AInfo: TSystemInfo; const ALinker: string);
  var lIndex: Integer;
  begin
    lIndex := Length(Targets);
    SetLength(Targets, lIndex + 1);
    Targets[lIndex].Name := AName;
    Targets[lIndex].Info := AInfo;
    Targets[lIndex].LinkerProgram := ALinker;
    ARegistry.AddSuite('Compiler.Clang.Assembler').AddTest(AName, @AssemblerRegistration, 'compiler-assembler');
    if ALinker <> '' then
      ARegistry.AddSuite('Compiler.Clang.Linker').AddTest(AName, @LinkerDefaults, 'compiler-linker');
  end;
begin
  Targets := nil;
  ARegistry.AddSuite('Compiler.Clang.Archives').AddTest('RetainedDrivers', @ArchiveRegistration, 'compiler-linker');
  {$if defined(TEST_I386)}
  AddTarget('I386Linux', System_I386_Linux_Info, 'ld.lld');
  AddTarget('I386Win32', System_I386_Win32_Info, '');
  {$elseif defined(TEST_AARCH64)}
  AddTarget('AArch64Linux', System_AArch64_Linux_Info, 'ld.lld');
  AddTarget('AArch64Win64', System_AArch64_Win64_Info, '');
  AddTarget('AArch64Android', System_AArch64_Android_Info, '');
  AddTarget('AArch64Darwin', System_AArch64_Darwin_Info, 'ld64.lld');
  AddTarget('AArch64IOS', System_AArch64_IOS_Info, 'ld64.lld');
  AddTarget('AArch64IPhoneSim', System_AArch64_IPhoneSim_Info, 'ld64.lld');
  {$else}
  AddTarget('X64Linux', System_X86_64_Linux_Info, 'ld.lld');
  AddTarget('X64Win64', System_X64_Win64_Info, '');
  AddTarget('X64Android', System_X86_64_Android_Info, '');
  AddTarget('X64Darwin', System_X86_64_Darwin_Info, 'ld64.lld');
  AddTarget('X64IPhoneSim', System_X86_64_IPhoneSim_Info, 'ld64.lld');
  {$endif}
end;
end.
