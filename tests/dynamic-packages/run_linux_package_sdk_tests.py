"""Build source-only glibc SDKs and test normal/smart, fresh/cached and relocation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def digest_tree(directory):
    return {p.relative_to(directory).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in directory.rglob('*') if p.is_file()}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--source-root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    root = args.source_root.resolve()
    out = (args.output or Path(tempfile.mkdtemp(prefix='nxpkg-linux-sdk-tests-', dir='/var/tmp'))).resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise ValueError('Output must be empty')
    print('Output:', out, flush=True)
    environment = os.environ.copy()
    environment['PATH'] = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
    environment['PYTHONDONTWRITEBYTECODE'] = '1'
    environment.pop('LD_LIBRARY_PATH', None)
    environment.pop('LD_PRELOAD', None)
    steps = []

    def record(name, **details):
        steps.append(dict(name=name, **details))
        (out / 'steps.json').write_text(json.dumps(steps, indent=2))
        print('PASS', name, flush=True)

    def run(name, command, expected=0, marker=None, cwd=out):
        command = list(map(str, command))
        log = out / (name + '.log')
        with log.open('w') as stream:
            result = subprocess.run(command, cwd=cwd, env=environment,
                                    stdout=stream, stderr=subprocess.STDOUT, timeout=2400)
        text = log.read_text(errors='replace')
        if result.returncode != expected or (marker and marker not in text):
            raise RuntimeError(f'{name}: exit {result.returncode}; {log}\n{text[-5000:]}')
        record(name, command=command, exit_code=result.returncode, log=str(log))

    # Include new source files but never ignored build products.
    names = subprocess.check_output(['git', '-c', 'safe.directory=' + str(root),
        'ls-files', '-z', '-c', '-o', '--exclude-standard', 'compiler', 'rtl', 'scripts',
        'examples', 'tests/dynamic-packages', 'tests/unit-exports'], cwd=root, env=environment)
    source = out / 'source'
    for name in set(names.decode().split('\0')) - {''}:
        if '__pycache__' in Path(name).parts:
            continue
        destination = source / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / name, destination)
    before = digest_tree(source)
    assert not (source / 'compiler/msgtxt.inc').exists()
    assert not (source / 'rtl/units').exists()
    record('source-only-input', files=len(before))

    for mode in ('normal', 'smart'):
        case = out / mode
        case.mkdir()
        sdk = case / 'sdk'
        smart = ['--smart'] if mode == 'smart' else []
        run(mode + '-sdk', [sys.executable, source / 'scripts/build_linux_package_sdk.py',
                           '--output-root', sdk, *smart])
        for cached in (False, True):
            run(mode + ('-cached' if cached else '-fresh'), [sys.executable,
                source / 'tests/dynamic-packages/run_linux_package_tests.py', '--sdk', sdk,
                '--output', case / ('cached' if cached else 'fresh'), *smart,
                *(['--cached'] if cached else [])])
        assert digest_tree(source) == before, 'SDK workflow modified its source input'
        record(mode + '-source-unchanged')

        if mode == 'normal':
            rtl = sdk / 'work/rtl-units'
            lifecycle = case / 'lifecycle'
            lifecycle.mkdir()
            run('lifecycle-build', [sdk / 'bin/ppcpkg', '-n', '-Mobjfpc', '-Cg',
                '-Fu' + str(rtl), '-Fu' + str(source / 'rtl/inc'), '-FU' + str(lifecycle),
                '-FE' + str(lifecycle), source / 'tests/dynamic-packages/package_lifecycle_test.pas'])
            run('lifecycle-runtime', [lifecycle / 'package_lifecycle_test'], marker='PASS lifecycle:')
            gas = case / 'external-assembler'
            gas.mkdir()
            (gas / 'GasUnit.pas').write_text('''unit GasUnit; {$mode objfpc}{$H+}
interface
type TGasValue = class Value: string; end;
function MakeGasValue: TGasValue;
implementation
function MakeGasValue: TGasValue;
begin Result:=TGasValue.Create; Result.Value:='GNU assembler'; end;
end.
''')
            (gas / 'gasprobe.ppk').write_text('package gasprobe; requires nxrtl; contains GasUnit; end.\n')
            identity = json.loads((sdk / 'sdk.json').read_text())['sdk_identity']
            run('external-assembler-package', [sdk / 'bin/ppcpkg', '-n', '-Cg', '-Aas', '-Mobjfpc',
                '-Fj' + identity, '-Fk' + 'a' * 32, '-Fu' + str(sdk / 'units'),
                '-Fp' + str(sdk / 'packages'), '-Fl' + str(sdk / 'packages'),
                '-FU' + str(gas), '-FE' + str(gas), '-k-rpath', '-k$ORIGIN', gas / 'gasprobe.ppk'])
            (gas / 'gas_host.pas').write_text('''program gas_host; {$mode objfpc}{$H+}
uses GasUnit;
var Value: TGasValue;
begin Value:=MakeGasValue; if (Value.ClassType<>TGasValue) or
  (Value.Value<>'GNU assembler') then Halt(1); Value.Free; WriteLn('PASS GNU assembler package'); end.
''')
            gas_host = case / 'gas-host'
            run('external-assembler-host', [sys.executable, sdk / 'bin/compile_linux_package.py',
                '--source', gas / 'gas_host.pas', '--kind', 'program', '--output', gas_host,
                '--package-path', gas, '--require', 'gasprobe'])
            generation = gas_host / json.loads((gas_host / 'current.json').read_text())['generation']
            run('external-assembler-runtime', [generation / 'gas_host'], marker='PASS GNU assembler package')
            # Rebuild the ordinary entry point against the matching RTL. It must
            # retain ordinary behavior and must not opt into package targets.
            production = case / 'production'
            production.mkdir()
            compiler_source = sdk / 'work/compiler-source'
            options = ['-n', '-O2', '-Cg', '-dx86_64', '-Fu' + str(rtl),
                       '-FU' + str(production), '-FE' + str(production)]
            for directory in ('', 'x86_64', 'x86', 'systems'):
                options += ['-Fu' + str(compiler_source / directory), '-Fi' + str(compiler_source / directory)]
            run('ordinary-compiler-build', [sdk / 'bin/ppcpkg', *options, compiler_source / 'pp.pas'])
            probe = production / 'unsupported.ppk'
            probe.write_text('package unsupported; end.\n')
            run('ordinary-rejects-packages', [production / 'pp', '-n', '-Fu' + str(rtl), probe],
                expected=1, marker='not supported')
            run('ordinary-linux-exports', [sys.executable, source / 'tests/unit-exports/Run-NXLinuxUnitExports.py',
                '--compiler', production / 'pp', '--rtl', rtl, '--output', case / 'ordinary-exports'])
            run('experimental-linux-exports', [sys.executable, source / 'tests/unit-exports/Run-NXLinuxUnitExports.py',
                '--compiler', sdk / 'bin/ppcpkg', '--rtl', rtl, '--output', case / 'experimental-exports'])

        relocated = case / 'relocated SDK'
        relocated.mkdir()
        for directory in ('bin', 'packages', 'units'):
            shutil.copytree(sdk / directory, relocated / directory)
        shutil.copy2(sdk / 'sdk.json', relocated)
        sdk_before = digest_tree(relocated)
        providers = case / 'providers-only'
        providers.mkdir()
        fresh = case / 'fresh'
        generation = fresh / 'packages' / json.loads((fresh / 'packages/current.json').read_text())['generation']
        for path in generation.iterdir():
            if path.suffix in ('.so', '.pcp'):
                shutil.copy2(path, providers)
        host_source = case / 'host-source'
        shutil.copytree(source / 'examples/dynamic-packages/late/host', host_source)
        hidden = [(source, out / 'source-unavailable'), (sdk, case / 'sdk-unavailable'),
                  (fresh, case / 'fresh-unavailable'), (case / 'cached', case / 'cached-unavailable')]
        moved = []
        try:
            for original, destination in hidden:
                assert original.resolve().is_relative_to(out) and destination.resolve().is_relative_to(out)
                original.rename(destination)
                moved.append((original, destination))
            app_dir = case / 'source-free-host'
            run(mode + '-source-free-build', [sys.executable, relocated / 'bin/compile_linux_package.py',
                '--sdk', relocated, '--source', host_source / 'late_console.pas', '--kind', 'program',
                '--output', app_dir, '--package-path', providers, '--require', 'democontracts', *smart])
            generation = app_dir / json.loads((app_dir / 'current.json').read_text())['generation']
            run(mode + '-source-free-runtime', [generation / 'late_console', case / 'source-free.log'],
                marker='PASS late package loading', cwd=Path('/'))
            assert digest_tree(relocated) == sdk_before
            record(mode + '-relocated-sdk-unchanged')
        finally:
            for original, destination in reversed(moved):
                destination.rename(original)
    assert digest_tree(source) == before
    record('source-unchanged')
    print(f'PASS {len(steps)} Linux SDK workflow checks. Logs: {out}', flush=True)


if __name__ == '__main__':
    main()
