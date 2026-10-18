{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
program CPUModels;

{$mode objfpc}

uses CPUInfo, Globals;

const
  cModels: array[0..22] of record
    CPU: TCPUType;
    Name: string[16];
  end = (
    (CPU: cpu_none; Name: ''),
    (CPU: cpu_athlon64; Name: 'ATHLON64'),
    (CPU: cpu_x86_64; Name: 'X86-64'),
    (CPU: cpu_x86_64_v1; Name: 'X86-64-V1'),
    (CPU: cpu_core_i; Name: 'COREI'),
    (CPU: cpu_x86_64_v2; Name: 'X86-64-V2'),
    (CPU: cpu_bobcat; Name: 'BOBCAT'),
    (CPU: cpu_core_avx; Name: 'COREAVX'),
    (CPU: cpu_jaguar; Name: 'JAGUAR'),
    (CPU: cpu_piledriver; Name: 'PILEDRIVER'),
    (CPU: cpu_excavator; Name: 'EXCAVATOR'),
    (CPU: cpu_core_avx2; Name: 'COREAVX2'),
    (CPU: cpu_x86_64_v3; Name: 'X86-64-V3'),
    (CPU: cpu_zen; Name: 'ZEN'),
    (CPU: cpu_zen2; Name: 'ZEN2'),
    (CPU: cpu_x86_64_v4; Name: 'X86-64-V4'),
    (CPU: cpu_skylake_x; Name: 'SKYLAKE-X'),
    (CPU: cpu_icelake; Name: 'ICELAKE'),
    (CPU: cpu_icelake_client; Name: 'ICELAKE-CLIENT'),
    (CPU: cpu_icelake_server; Name: 'ICELAKE-SERVER'),
    (CPU: cpu_zen3; Name: 'ZEN3'),
    (CPU: cpu_zen4; Name: 'ZEN4'),
    (CPU: cpu_zen5; Name: 'ZEN5')
  );

var
  lIndex, lFailures, lChecks: LongInt;
  lSettings: TSettings;
  lCPU: TCPUType;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  Inc(lChecks);
  if not ACondition then
  begin
    WriteLn('FAIL: ', AMessage);
    Inc(lFailures);
  end;
end;

begin
  Check(Ord(High(TCPUType)) = High(cModels), 'CPU model coverage');
  for lIndex := Low(cModels) to High(cModels) do
  begin
    Check(CPUTypeStr[cModels[lIndex].CPU] = cModels[lIndex].Name,
      'name: ' + cModels[lIndex].Name);
    { Explicit option slots are also stored in generic token settings. }
    Check(Ord(cModels[lIndex].CPU) = lIndex,
      'saved slot: ' + cModels[lIndex].Name);
    if lIndex = 0 then
      Continue;
    lSettings := Default_Settings;
    Check(SetCPUType(cModels[lIndex].Name, lSettings),
      '-Cp accepts ' + cModels[lIndex].Name);
    Check(lSettings.CPUType = cModels[lIndex].CPU,
      '-Cp selects ' + cModels[lIndex].Name);
    lCPU := cpu_none;
    Check(SetOptimizeCPUType(cModels[lIndex].Name, lCPU),
      '-Op accepts ' + cModels[lIndex].Name);
    Check(lCPU = cModels[lIndex].CPU,
      '-Op selects ' + cModels[lIndex].Name);
  end;
  Check(Default_Settings.CPUType = cpu_athlon64, 'default CPU');
  Check(Default_Settings.OptimizeCPUType = cpu_athlon64, 'default optimizer CPU');
  Check(CPUTypeStr[Default_Settings.CPUType] = 'ATHLON64', 'default CPU name');
  Check(cpu_capabilities[cpu_athlon64] = cpu_x86_64_v1_flags, 'Athlon64 features');
  Check(cpu_capabilities[cpu_x86_64] = cpu_x86_64_v1_flags, 'X86-64 features');
  Check(cpu_capabilities[cpu_x86_64_v1] = cpu_x86_64_v1_flags, 'V1 features');
  Check(cpu_capabilities[cpu_core_i] = cpu_x86_64_v1_flags +
    [CPUX86_HAS_SSSE3, CPUX86_HAS_SSE4_1, CPUX86_HAS_POPCNT], 'Core i features');
  Check(cpu_capabilities[cpu_x86_64_v2] = cpu_x86_64_v2_flags, 'V2 features');
  if lFailures <> 0 then
    Halt(1);
  WriteLn('PASS: ', lChecks, ' CPU model checks');
end.
