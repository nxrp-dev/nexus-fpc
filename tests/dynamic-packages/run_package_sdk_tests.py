"""Validate the documented SDK workflow from source and after binary relocation."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile


def quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def selected(directory):
    current = directory / 'current.json'
    if current.exists():
        return directory / json.loads(current.read_text(encoding='utf-8-sig'))['Generation']
    return directory


def digest_tree(directory):
    return {str(p.relative_to(directory)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in directory.rglob('*') if p.is_file()}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--output-root', type=Path)
    parser.add_argument('--build-timeout', type=int, default=1800,
                        help='Seconds allowed for each fresh compiler/RTL/SDK build (default: 1800)')
    parser.add_argument('--bootstrap-bin', type=Path,
                        default=Path(r'C:\lazarus\fpc\3.2.2\bin\x86_64-win64'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = (args.output_root or Path(tempfile.mkdtemp(prefix='nxpkg-sdk-'))).resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise RuntimeError('Output root must be empty')
    steps = []
    print('Output:', out, flush=True)

    def record(name, **details):
        steps.append(dict(name=name, **details))
        (out / 'steps.json').write_text(json.dumps(steps, indent=2))
        print('PASS', name, flush=True)

    def run(name, command, cwd=out):
        log = out / (name + '.log')
        with log.open('w') as stream:
            process = subprocess.run([str(x) for x in command], cwd=cwd, stdout=stream,
                                     stderr=subprocess.STDOUT,
                                     timeout=args.build_timeout if name.endswith('-build-and-run') else 600)
        if process.returncode:
            raise RuntimeError(f'{name}: exit {process.returncode}; details: {log}')
        record(name, command=[str(x) for x in command], log=str(log), exit_code=0)

    def powershell(name, expression):
        script = out / (name + '.ps1')
        # Keep native diagnostics in their step logs and the terminal summary plain.
        script.write_text("$ErrorActionPreference = 'Stop'\ntry {\n" + expression +
                          "\n} catch { Write-Output $_.Exception.Message; exit 1 }\n")
        run(name, ['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script])

    def move_within_output(source, destination):
        assert source.resolve().is_relative_to(out)
        assert destination.resolve().is_relative_to(out)
        source.rename(destination)

    # Include new source files during development, but never ignored build artifacts.
    source = out / 'source'
    paths = subprocess.check_output(['git', 'ls-files', '-z', '-c', '-o', '--exclude-standard',
                                     'compiler', 'rtl', 'scripts', 'examples'], cwd=root)
    for name in set(paths.decode().split('\0')) - {''}:
        destination = source / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / name, destination)
    before = digest_tree(source)
    assert not (source / 'compiler/msgtxt.inc').exists()
    assert not (source / 'rtl/units').exists()
    record('source-only-input', files=len(before))

    for smart in (False, True):
        case = out / ('smart' if smart else 'normal')
        case.mkdir()
        sdk = case / 'sdk'
        mode = case.name
        smart_flag = ' -SmartLink' if smart else ''
        powershell(mode + '-build-and-run',
                   '& ' + quote(source / 'scripts/Build-NexusFPCPackageSDK.ps1') +
                   ' -SourceRoot ' + quote(source) + ' -OutputRoot ' + quote(sdk) +
                   ' -BootstrapBin ' + quote(args.bootstrap_bin) + ' -RunExamples' + smart_flag)
        assert digest_tree(source) == before, 'SDK build modified its input source tree'
        record(mode + '-source-unchanged')

        relocated = case / 'relocated-sdk'
        relocated.mkdir()
        for directory in ('bin', 'packages', 'units'):
            shutil.copytree(sdk / directory, relocated / directory)
        shutil.copy2(sdk / 'sdk.json', relocated)
        providers = case / 'package-distribution'
        providers.mkdir()
        for file in selected(sdk / 'examples/packages').iterdir():
            if file.suffix in ('.pcp', '.dll'):
                shutil.copy2(file, providers)
        assert len(list(providers.iterdir())) == 8
        host_source = case / 'host-source'
        shutil.copytree(source / 'examples/dynamic-packages/host', host_source)
        assert {p.suffix for p in host_source.iterdir()} == {'.pas'}
        binaries_before = digest_tree(relocated)
        # Break even absolute source/object/PPU paths recorded by the original build.
        hidden_source = out / 'source-unavailable'
        move_within_output(source, hidden_source)
        move_within_output(sdk, case / 'sdk-unavailable')
        try:
            for kind, subsystem in (('console', 3), ('gui', 2)):
                name = 'demo_' + kind
                app = case / name
                powershell(mode + '-relocated-build-' + kind,
                           '& ' + quote(relocated / 'bin/Invoke-NexusFPCPackageCompile.ps1') +
                           ' -SdkRoot ' + quote(relocated) + ' -Source ' +
                           quote(host_source / (name + '.pas')) + ' -OutputDirectory ' + quote(app) +
                           ' -Kind ' + kind + ' -PackagePath ' + quote(providers) +
                           " -RequiredPackages @('demotypes','demoleft','demoright')" + smart_flag)
                # Execute from an unrelated directory with only application-side DLLs.
                app = selected(app)
                result = app / 'result.log'
                run(mode + '-relocated-run-' + kind, [app / (name + '.exe'), result])
                assert result.read_text().splitlines() == [
                    'init=BLRH', 'PASS ' + kind, 'final=h', 'final=r', 'final=l', 'final=b']
                image = (app / (name + '.exe')).read_bytes()
                pe = struct.unpack_from('<I', image, 0x3c)[0]
                assert image[pe:pe + 4] == b'PE\0\0'
                assert struct.unpack_from('<H', image, pe + 4)[0] == 0x8664
                assert struct.unpack_from('<H', image, pe + 24 + 68)[0] == subsystem
                assert {p.name for p in app.glob('*.dll')} == {
                    'nxrtl.dll', 'demotypes.dll', 'demoleft.dll', 'demoright.dll'}
                record(mode + '-relocated-lifecycle-and-subsystem-' + kind)
            assert digest_tree(relocated) == binaries_before
            record(mode + '-sdk-artifacts-unchanged')
        finally:
            move_within_output(hidden_source, source)
    print(f'PASS {len(steps)} SDK workflow checks. Logs: {out}', flush=True)


if __name__ == '__main__':
    main()
