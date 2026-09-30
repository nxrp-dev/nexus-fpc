program NXSystemIds;

{$mode objfpc}
{$packenum 1}
{$packset 1}
{$R+}

{$I ../../compiler/systems.inc}

type
  TNXCPUSet = set of TSystemCPU;
  TNXSystemSet = set of TSystem;

procedure CheckOrdinal(const AName: ShortString; AActual, AExpected: LongInt);
begin
  if AActual <> AExpected then
    begin
      WriteLn(AName, ': expected ', AExpected, ', got ', AActual);
      Halt(1);
    end;
end;

var
  CPUs: TNXCPUSet;
  Targets: TNXSystemSet;
  CPUValues: array[0..Ord(High(TSystemCPU))] of LongInt;
  SystemValues: array[0..Ord(High(TSystem))] of LongInt;
begin
  CheckOrdinal('cpu_no', Ord(cpu_no), 0);
  CheckOrdinal('cpu_i386', Ord(cpu_i386), 1);
  CheckOrdinal('cpu_x86_64', Ord(cpu_x86_64), 8);
  CheckOrdinal('cpu_aarch64', Ord(cpu_aarch64), 16);
  CheckOrdinal('last stored CPU ID', MaxStoredCPUId, 25);
  CheckOrdinal('system_none', Ord(system_none), 0);
  CheckOrdinal('system_i386_linux', Ord(system_i386_linux), 3);
  CheckOrdinal('system_i386_Win32', Ord(system_i386_Win32), 5);
  CheckOrdinal('system_x86_64_linux', Ord(system_x86_64_linux), 26);
  CheckOrdinal('system_x86_64_win64', Ord(system_x86_64_win64), 37);
  CheckOrdinal('system_i386_darwin', Ord(system_i386_darwin), 44);
  CheckOrdinal('system_x86_64_darwin', Ord(system_x86_64_darwin), 61);
  CheckOrdinal('system_i386_nativent', Ord(system_i386_nativent), 68);
  CheckOrdinal('system_i386_iphonesim', Ord(system_i386_iphonesim), 69);
  CheckOrdinal('system_i386_android', Ord(system_i386_android), 78);
  CheckOrdinal('system_aarch64_ios', Ord(system_aarch64_ios), 86);
  CheckOrdinal('system_x86_64_iphonesim', Ord(system_x86_64_iphonesim), 87);
  CheckOrdinal('system_aarch64_linux', Ord(system_aarch64_linux), 88);
  CheckOrdinal('system_aarch64_android', Ord(system_aarch64_android), 100);
  CheckOrdinal('system_x86_64_android', Ord(system_x86_64_android), 101);
  CheckOrdinal('system_aarch64_win64', Ord(system_aarch64_win64), 107);
  CheckOrdinal('system_aarch64_darwin', Ord(system_aarch64_darwin), 111);
  CheckOrdinal('system_aarch64_iphonesim', Ord(system_aarch64_iphonesim), 121);
  CheckOrdinal('CPU size', SizeOf(TSystemCPU), 1);
  CheckOrdinal('System size', SizeOf(TSystem), 1);
  CheckOrdinal('CPU set size', SizeOf(TNXCPUSet), 3);
  CheckOrdinal('System set size', SizeOf(TNXSystemSet), 16);
  CheckOrdinal('highest CPU ID', Ord(High(TSystemCPU)), 16);
  CheckOrdinal('highest system ID', Ord(High(TSystem)), 121);
  CheckOrdinal('last stored system ID', MaxStoredSystemId, 126);
  CPUs := [cpu_i386, cpu_x86_64, cpu_aarch64];
  Targets := [system_x86_64_linux, system_x86_64_win64, system_x86_64_android];
  CPUValues[Ord(cpu_i386)] := 1;
  CPUValues[Ord(cpu_x86_64)] := 8;
  CPUValues[Ord(cpu_aarch64)] := 16;
  SystemValues[Ord(system_x86_64_linux)] := 26;
  SystemValues[Ord(system_x86_64_win64)] := 37;
  SystemValues[Ord(system_x86_64_android)] := 101;
  if not ((cpu_i386 in CPUs) and (cpu_x86_64 in CPUs) and
          (cpu_aarch64 in CPUs)) then Halt(2);
  if not ((system_x86_64_linux in Targets) and
          (system_x86_64_win64 in Targets) and
          (system_x86_64_android in Targets)) then Halt(3);
  CheckOrdinal('i386 CPU index', CPUValues[Ord(cpu_i386)], 1);
  CheckOrdinal('x86-64 CPU index', CPUValues[Ord(cpu_x86_64)], 8);
  CheckOrdinal('AArch64 CPU index', CPUValues[Ord(cpu_aarch64)], 16);
  CheckOrdinal('Linux system index', SystemValues[Ord(system_x86_64_linux)], 26);
  CheckOrdinal('Win64 system index', SystemValues[Ord(system_x86_64_win64)], 37);
  CheckOrdinal('Android system index', SystemValues[Ord(system_x86_64_android)], 101);
  WriteLn('PASS: surviving CPU and system IDs, sizes, sets, and numeric indexes');
end.
