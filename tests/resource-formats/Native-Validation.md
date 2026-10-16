# LLVM resource migration native validation

Native Windows, Android and Apple execution was waived by the owner on
16 October 2026. Code review, cross-target objects/linked artifacts, metadata
compatibility and the stock-seeded Linux bootstrap remain acceptance checks.
The commands below are optional follow-up execution checks.

The checked-in helpers now use the production compiler pipeline directly.
The earlier ZIP bundle used prototype object substitution and is historical
evidence. It must not be used to prove the integrated path.

Host suites validate normalization, LLVM RC invocation, encoding diagnostics,
artifact publication and metadata readers. The Unix host runner also runs
compiler integration and CRC32/hash regressions when given a Nexus compiler.
Use fresh external output directories and matching compiler/RTL pairs.

## Windows host checks

Use the current checkout or export it to a short source path. The historical
prototype ZIP is not the current source. Supply LLVM Clang, llvm-rc and llvm-cvtres
on PATH, or use the runner's explicit tool-path parameters. Run stock FPC 3.2.2
with its stock RTL, then Nexus with its matching RTL in a separate output.

```powershell
$bundle = 'D:\source\nexus-fpc'
& "$bundle\tests\resource-formats\Run-NXResourceHostChecks.ps1" `
  -Compiler 'C:\fpc\3.2.2\bin\i386-win32\ppc386.exe' `
  -RtlUnits 'C:\fpc\3.2.2\units\i386-win32\rtl' `
  -ArtifactRoot 'D:\worktree\resource-host-stock'

& "$bundle\tests\resource-formats\Run-NXResourceHostChecks.ps1" `
  -Compiler $NexusCompiler -RtlUnits $MatchingNexusRTL -NexusCompiler `
  -ArtifactRoot 'D:\worktree\resource-host-nexus'
```

`host.json`, `commands.json` and `logs/` identify the compiler and failures.
The PowerShell runners require native validation; they have not been executed
on the Linux development host. Binary files under `tests/resource-formats/fixtures/metadata` are reader
inputs, not programs to launch.

## macOS host checks

Use matching native compiler/RTL pairs and LLVM tools with all retained target
backends. The script runs the standalone suites, cross-object/link inspections
and metadata checks. A cross-link pass is separate from native execution.

```bash
bash "$bundle/tests/resource-formats/Run-NXResourceHostChecks.sh" \
  "$compiler" "$matching_rtl" "$external_output"
```

## Prepare a target runtime check

Use a Nexus compiler built for the target CPU and that target's matching RTL.
Keep existing SDK/sysroot and linker settings in an explicit configuration.
The preparation scripts use `-n`; pass the appropriate explicit configuration
as an additional compiler argument. A stock compiler cannot accept Nexus
assembler/linker switches in this stage.

Generate the canonical table fixture with the table suite; its output is
`<table-output>/tables.res`. The runtime helper copies that fixture and compiles
`nxResourceRuntimeTests.pas` through the integrated path, without a converter
or object substitution.

```bash
bash "$source/tests/resource-formats/Prepare-NXResourceRuntimeCheck.sh" \
  "$target_compiler" "$target_rtl" "$target_os" \
  "$table_output/tables.res" "$runtime_output" "@$explicit_target_config"
```

Use target OS names `linux`, `android`, `darwin`, `iphonesim`, or `ios`.
For Windows:

```powershell
& "$source\tests\resource-formats\Prepare-NXResourceRuntimeCheck.ps1" `
  -Compiler $TargetCompiler -RtlUnits $TargetRTL -TargetOS win64 `
  -FixtureRes "$TableOutput\tables.res" -ArtifactRoot $RuntimeOutput `
  -CompilerArguments @("@$ExplicitTargetConfig")
```

Select `win32` for i386 and `win64` for x86_64/ARM64. Execute each resulting
program on its matching Windows architecture:

```powershell
& "$RuntimeOutput\nxResourceRuntimeTests.exe" > "$RuntimeOutput\runtime.log" 2>&1
$LASTEXITCODE | Set-Content "$RuntimeOutput\runtime.exit"
```

The test checks every resource identity, language and payload, repeated handles,
enumeration, missing lookups and streams. Windows uses native wide APIs for
Unicode identities and the existing RTL ANSI contract for ASCII streams; it
does not assume a particular Windows ANSI codepage. The Windows RTL's legacy
free/unlock return convention is preserved. Linux/macOS use the RTL resource
API for all identifiers, including Unicode stream names.

## Linux and macOS execution

Run the prepared executable on a matching CPU/OS and preserve its exit status:

```bash
"$runtime_output/nxResourceRuntimeTests" >"$runtime_output/runtime.log" 2>&1
result=$?
printf '%s\n' "$result" >"$runtime_output/runtime.exit"
```

For ARM64 macOS, apply the normal local development signature if required by
the configured linker output. Do not substitute an Intel run for an ARM64 row.

## Android execution

Prepare with the established NDK configuration and a matching API level, then
run on the matching device/emulator ABI. These commands use standard
[ADB file transfer and shell operations](https://developer.android.com/tools/adb).

```bash
adb -s "$serial" shell mkdir -p /data/local/tmp/nx-resource-check
adb -s "$serial" push "$runtime_output/nxResourceRuntimeTests" /data/local/tmp/nx-resource-check/
adb -s "$serial" push "$runtime_output/runtimetables.res" /data/local/tmp/nx-resource-check/
adb -s "$serial" shell chmod 700 /data/local/tmp/nx-resource-check/nxResourceRuntimeTests
adb -s "$serial" shell /data/local/tmp/nx-resource-check/nxResourceRuntimeTests \
  >/tmp/nx-resource-android-runtime.log 2>&1
result=$?
printf '%s\n' "$result" >/tmp/nx-resource-android-runtime.exit
adb -s "$serial" shell getprop ro.product.cpu.abi
```

## Simulator and iOS execution

Use Xcode's matching SDK, installed runtime and device. Package the prepared
Mach-O test, including its expected RES fixture:

```bash
bash "$bundle/tests/resource-formats/Package-NXResourceRuntimeApp.sh" \
  "$runtime_output" "$bundle_id" iPhoneSimulator "$app"
codesign --force --sign - "$app"
xcrun simctl install booted "$app"
xcrun simctl launch --console-pty booted "$bundle_id"
```

Apple demonstrates the console launch interface in its
[Simulator command-line session](https://devstreaming-cdn.apple.com/videos/wwdc/2019/418o9bbtoe880sauh/418/418_getting_the_most_out_of_simulator.pdf).
Use an Intel simulator for x86_64 and an ARM64 simulator for ARM64. Preserve the
console transcript; a successful launch alone does not establish a test pass.

For a device, package with `iPhoneOS` instead. Use the project's normal valid
development signing identity, matching bundle identifier, entitlements and
provisioning profile before installation. The unsigned bundle helper has not
been run on Apple hardware. Signing, installation and launch need native
validation as well as the Pascal test itself.

```bash
xcrun devicectl device install app --device "$device_id" "$signed_app"
xcrun devicectl device process launch --console --device "$device_id" "$bundle_id"
```

The console option captures stdout/stderr and waits for app exit in
[Xcode 16 and later](https://developer.apple.com/documentation/xcode-release-notes/xcode-16-release-notes).
Require the Pascal `PASS native resource APIs` line and normal zero exit;
retain any crash, signing or tool failure for analysis.

## Return results

Return host/target CPU and OS version, compiler/RTL identity, LLVM/SDK version,
command logs, runtime stdout/stderr and exit status. Keep each target in its own
directory. Native execution remains waived unless the owner requests it again;
never report an artifact inspection or successful launch as a runtime pass.
