program NXClangRegistration;

{$mode objfpc}{$H+}

uses
  GlobType, Systems, Triplet, I_Linux, I_Win,
  {$ifndef TEST_I386}I_Android, I_Darwin,{$endif}
  {$ifdef TEST_AARCH64}AGCPUGAS{$else}AGX86ATT{$endif};

procedure CheckTarget(const AInfo: TSystemInfo);
var
  ExpectedAssembler: TAsm;
  UseExternal: Boolean;
begin
  TargetInfo := AInfo;
  if AInfo.System in Systems_Darwin then
    ExpectedAssembler := As_Clang_AsDarwin
  else
    ExpectedAssembler := As_Clang_Gas;
  for UseExternal := False to True do
    begin
      if UseExternal then
        begin
          if not SetTargetAsm(AInfo.AssemExtern) then
            Halt(1);
        end
      else if not SetTargetAsm(AInfo.Assem) then
        Halt(2);
      if (TargetAsm.Id <> ExpectedAssembler) or (TargetAsm.AsmBin <> 'clang') or
         not (AF_LLVM in TargetAsm.Flags) or (TargetTriplet(Triplet_LLVM) = '') then
        Halt(3);
    end;
  WriteLn(AInfo.Name, ': ', TargetTriplet(Triplet_LLVM), ' -> ', TargetAsm.AsmBin);
end;

begin
  {$if defined(TEST_I386)}
  CheckTarget(System_I386_Linux_Info);
  CheckTarget(System_I386_Win32_Info);
  {$elseif defined(TEST_AARCH64)}
  CheckTarget(System_AArch64_Linux_Info);
  CheckTarget(System_AArch64_Win64_Info);
  CheckTarget(System_AArch64_Android_Info);
  CheckTarget(System_AArch64_Darwin_Info);
  CheckTarget(System_AArch64_IOS_Info);
  CheckTarget(System_AArch64_IPhoneSim_Info);
  {$else}
  CheckTarget(System_X86_64_Linux_Info);
  CheckTarget(System_X64_Win64_Info);
  CheckTarget(System_X86_64_Android_Info);
  CheckTarget(System_X86_64_Darwin_Info);
  CheckTarget(System_X86_64_IPhoneSim_Info);
  {$endif}
end.
