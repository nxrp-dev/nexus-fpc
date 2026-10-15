program NXLLDDefaults;
{$mode objfpc}{$H+}
uses
  GlobType, Globals, Systems, Link, I_Linux, T_Linux
  {$ifndef TEST_I386}, I_Darwin, T_Darwin{$endif};
procedure Check(const AInfo: TSystemInfo; const AProgram: String);
var
  Instance: TExternalLinker;
begin
  CurrentSettings := Default_Settings;
  if not (CS_Link_LLD in CurrentSettings.GlobalSwitches) then Halt(1);
  TargetInfo := AInfo;
  InitLinker;
  if not (Linker is TExternalLinker) then Halt(4);
  Instance := TExternalLinker(Linker);
  try
    if (Pos(AProgram + ' ', Instance.Info.ExeCmd[1]) <> 1) or
       (Pos(AProgram + ' ', Instance.Info.DllCmd[1]) <> 1) then Halt(2);
  finally
    DoneLinker;
  end;
  Exclude(CurrentSettings.GlobalSwitches, CS_Link_LLD);
  InitLinker;
  if not (Linker is TExternalLinker) then Halt(4);
  Instance := TExternalLinker(Linker);
  try
    if (Pos('ld ', Instance.Info.ExeCmd[1]) <> 1) or
       (Pos('ld ', Instance.Info.DllCmd[1]) <> 1) then Halt(3);
  finally
    DoneLinker;
  end;
  WriteLn(AInfo.Name, ': default ', AProgram, '; explicit override retained');
end;

begin
  DontLinkStdlibPath := True;
  {$if defined(TEST_I386)}
  Check(System_I386_Linux_Info, 'ld.lld');
  {$elseif defined(TEST_AARCH64)}
  Check(System_AArch64_Linux_Info, 'ld.lld');
  Check(System_AArch64_Darwin_Info, 'ld64.lld');
  Check(System_AArch64_IOS_Info, 'ld64.lld');
  Check(System_AArch64_IPhoneSim_Info, 'ld64.lld');
  {$else}
  Check(System_X86_64_Linux_Info, 'ld.lld');
  Check(System_X86_64_Darwin_Info, 'ld64.lld');
  Check(System_X86_64_IPhoneSim_Info, 'ld64.lld');
  {$endif}
end.
