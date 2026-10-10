"""Execute glibc package startup, late loading, cleanup and publication regressions."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from linux_package_artifacts import ELF, bundle, digest, publish


def inspect(directory):
    class Descriptor(ctypes.Structure):
        _fields_ = [('w', ctypes.c_size_t * 21)]
    libraries = []
    for name in ('nxrtl', 'democontracts', 'pluginbase', 'pluginleft', 'pluginright'):
        lib = ctypes.CDLL(str(directory / ('lib' + name + '.so')), mode=os.RTLD_NOW)
        libraries.append(lib)
        address = ctypes.c_void_p.in_dll(lib, 'FPC_PACKAGE_INFO').value
        words = Descriptor.from_address(address).w
        assert tuple(words[:3]) == (0x4e58504b, 3, 168)
        assert list((ctypes.c_size_t * 6).from_address(words[16])) == [0] * 6
    print('PASS native mapping does not activate Pascal packages')


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--sdk', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--smart', action='store_true')
    parser.add_argument('--cached', action='store_true', help='Build example packages from source-hidden standalone units.')
    parser.add_argument('--inspect', type=Path)
    args = parser.parse_args()
    if args.inspect:
        inspect(args.inspect.resolve())
        return
    if args.sdk is None:
        parser.error('--sdk is required')
    sdk = args.sdk.resolve()
    out = (args.output or Path(tempfile.mkdtemp(prefix='nxpkg-linux-tests-', dir='/var/tmp'))).resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise ValueError('Output must be empty')
    print('Output:', out, flush=True)
    sdk_manifest = json.loads((sdk / 'sdk.json').read_text())
    steps = []
    environment = os.environ.copy()
    environment['PATH'] = '/usr/local/bin:/usr/bin:/bin'
    environment.pop('LD_LIBRARY_PATH', None)
    environment.pop('LD_PRELOAD', None)

    def record(name, **details):
        steps.append(dict(name=name, **details))
        (out / 'steps.json').write_text(json.dumps(steps, indent=2))
        print('PASS', name, flush=True)

    def run(name, command, expected=0, marker=None, cwd=out):
        log = out / (name + '.log')
        with log.open('w') as stream:
            result = subprocess.run(list(map(str, command)), cwd=cwd, env=environment,
                                    stdout=stream, stderr=subprocess.STDOUT, timeout=900)
        text = log.read_text(errors='replace')
        if result.returncode != expected or (marker and marker not in text):
            raise RuntimeError(f'{name}: exit {result.returncode}; {log}\n{text[-5000:]}')
        record(name, command=list(map(str, command)), exit_code=result.returncode, log=str(log))
        return text

    compiler = sdk / 'bin/compile_linux_package.py'
    providers = out / 'packages'
    providers.mkdir()

    def compile(name, source, kind='package', required=(), output=providers, paths=(), expected=0, marker=None):
        command = [sys.executable, compiler, '--sdk', sdk, '--source', source,
                   '--kind', kind, '--output', output, '--package-path', providers]
        for p in paths:
            command += ['--package-path', p]
        for p in required:
            command += ['--require', p]
        if args.smart:
            command += ['--smart']
        snapshots = {}
        hidden = []
        if args.cached and kind == 'package' and expected == 0 and source.is_relative_to(out / 'source'):
            declaration = source.read_text()
            units = re.search(r'contains\s+(.*?);', declaration, re.I | re.S)[1].split(',')
            requirements = re.search(r'requires\s+(.*?);', declaration, re.I | re.S)[1].split(',')
            unit_command = [sdk / 'bin/ppcpkg', '-n', '-Mobjfpc', '-Cg',
                '-Fj' + sdk_manifest['sdk_identity'], '-Fu' + str(sdk / 'units'),
                '-Fu' + str(source.parent), '-FU' + str(source.parent), '-FE' + str(source.parent)]
            for directory in (sdk / 'packages', bundle(providers)):
                unit_command += ['-Fp' + str(directory), '-Fl' + str(directory)]
            unit_command += ['-FP' + p.strip() for p in requirements]
            if args.smart:
                unit_command += ['-CX', '-XX']
            for unit_name in units:
                path = next(p for p in source.parent.iterdir() if p.suffix.lower() in ('.pas', '.pp')
                            and p.stem.casefold() == unit_name.strip().casefold())
                run('cache-' + name + '-' + path.stem, [*unit_command, path])
            for path in source.parent.iterdir():
                if path.suffix in ('.ppu', '.o', '.a'):
                    snapshots[path] = digest(path)
                elif path.suffix in ('.pas', '.pp'):
                    path.rename(path.with_name(path.name + '.hidden'))
                    hidden.append(path)
        try:
            result = run('build-' + name, command, expected, marker)
            if snapshots:
                assert snapshots == {p: digest(p) for p in snapshots}, 'Cached units changed'
                record('cached-' + name + '-unchanged')
            return result
        finally:
            for path in hidden:
                path.with_name(path.name + '.hidden').rename(path)

    source = out / 'source'
    shutil.copytree(ROOT / 'examples/dynamic-packages', source)
    for name in ('demotypes', 'demoleft', 'demoright'):
        compile(name, source / name / (name + '.ppk'))
    startup = out / 'startup'
    compile('startup', source / 'host/demo_console.pas', 'program',
            ('demotypes', 'demoleft', 'demoright'), startup)
    app = bundle(startup) / 'demo_console'
    result = out / 'startup-result.log'
    run('startup-runtime', [app, result], marker='PASS console package host')
    assert result.read_text().splitlines() == ['init=BLRH', 'PASS console', 'final=h', 'final=r', 'final=l', 'final=b']
    record('startup-lifecycle-order')
    relocations = run('startup-relocations', ['readelf', '-rW', app])
    assert 'R_X86_64_COPY' not in relocations
    record('no-copy-relocations')

    late = source / 'late'
    run('resource-build', ['fpcres', '-of', 'res', late / 'base/pluginbase.rc', '-o', late / 'base/pluginbase.res'])
    for directory, name in (('contracts', 'democontracts'), ('base', 'pluginbase'),
                            ('left', 'pluginleft'), ('right', 'pluginright')):
        compile(name, late / directory / (name + '.ppk'))
    run('inspect-without-activation', [sys.executable, __file__, '--inspect', bundle(providers)])
    host = out / 'late-host'
    compile('late-host', late / 'host/late_console.pas', 'program', ('democontracts',), host)
    app = bundle(host) / 'late_console'
    dynamic = run('late-dependencies', ['readelf', '-dW', app])
    assert 'libdemocontracts.so' in dynamic
    assert 'libpluginleft.so' not in dynamic and 'libpluginbase.so' not in dynamic
    record('genuinely-late')
    result = out / 'late-result.log'
    run('late-runtime', [app, result], marker='PASS late package loading')
    assert result.read_text().splitlines() == ['PASS late console', 'CBLRlrbBLlb']
    record('late-lifecycle-order')

    def runtime_copy(directory, image):
        directory.mkdir()
        for p in image.parent.iterdir():
            if p.suffix == '.so' or p == image:
                shutil.copy2(p, directory)
        return directory / image.name

    relocated = runtime_copy(out / 'runtime only', app)
    run('relocated-runtime', [relocated, out / 'relocated.log'], cwd=Path('/'), marker='PASS late package loading')
    for mismatch in ('abi', 'sdk', 'dependency'):
        rejected = runtime_copy(out / ('startup-' + mismatch), app)
        path = rejected.parent / 'libdemocontracts.so'
        alter(path, mismatch)
        run('startup-reject-' + mismatch, [rejected], expected=217, marker='Package startup failed: EPackageError:')

    fixtures = out / 'fixtures'
    fixtures.mkdir()

    def unit(name, declarations='', initialization='', finalization=''):
        return f'''unit {name}; {{$mode objfpc}}{{$H+}}
interface
uses SysUtils, Classes, PkgContracts;
implementation
{declarations}
initialization
{initialization}
finalization
{finalization}
end.
'''

    def package(name, units, requires='nxrtl, democontracts'):
        directory = fixtures / name
        directory.mkdir()
        for name_, content in units.items():
            (directory / (name_ + '.pas')).write_text(content)
        path = directory / (name + '.ppk')
        path.write_text('package ' + name + '; requires ' + requires + '; contains ' + ','.join(units) + '; end.\n')
        compile(name, path)

    error_class = '''type ELocalFailure = class(Exception) destructor Destroy; override; end;
destructor ELocalFailure.Destroy;
begin Trace:=Trace+'D'; inherited Destroy; end;
'''
    package('failinit', {
        'FailFirst': unit('FailFirst', initialization="Trace:=Trace+'F';", finalization="Trace:=Trace+'f';"),
        'FailLast': unit('FailLast', error_class + 'type TFailedClass = class(TPersistent);',
            "Trace:=Trace+'!'; RegisterClassAlias(TFailedClass,'FailedAlias'); raise ELocalFailure.Create('init-marker');")})
    package('faildependency', {'FailDependencyUnit': unit('FailDependencyUnit', error_class,
        "Trace:=Trace+'!'; raise ELocalFailure.Create('init-marker');")}, 'nxrtl, democontracts, pluginbase')
    package('cleanupfail', {
        'CleanupFirst': unit('CleanupFirst', initialization="Trace:=Trace+'X';",
            finalization="Trace:=Trace+'x'; raise Exception.Create('cleanup-marker');"),
        'CleanupLast': unit('CleanupLast', error_class, "Trace:=Trace+'!'; raise ELocalFailure.Create('init-marker');")},
        'nxrtl, democontracts, pluginbase')
    package('failfini', {'FailFiniUnit': unit('FailFiniUnit', error_class, "Trace:=Trace+'Z';",
        "Trace:=Trace+'z'; raise ELocalFailure.Create('finalization-marker');")})
    package('callbackfail', {'CallbackFailUnit': unit('CallbackFailUnit', error_class +
        "procedure FailedCleanup; begin Trace:=Trace+'K'; raise ELocalFailure.Create('callback-marker'); end;",
        "Trace:=Trace+'Y'; RegisterPackageCleanup(PackageModuleFromAddress(@FailedCleanup),@FailedCleanup);", "Trace:=Trace+'y';")})
    package('newtls', {'NewTLSUnit': unit('NewTLSUnit', 'threadvar Value: LongInt;', "if Value<>0 then raise Exception.Create('TLS not zero'); Value:=42; Trace:=Trace+'T';",
        "if Value<>42 then raise Exception.Create('TLS lost before finalization'); Trace:=Trace+'t';")})
    package('nestedload', {'NestedLoadUnit': unit('NestedLoadUnit', initialization="Trace:=Trace+'Q'; LoadPackage('libpluginleft.so');")})
    package('nestedunload', {'NestedUnloadUnit': unit('NestedUnloadUnit', 'procedure Marker; begin end;',
        "Trace:=Trace+'U';", "Trace:=Trace+'u'; UnloadPackage(PackageModuleFromAddress(@Marker));")})
    package('nonexception', {'NonExceptionUnit': unit('NonExceptionUnit',
        "type TLocalError = class(TObject) destructor Destroy; override; end;\n"
        "destructor TLocalError.Destroy; begin Trace:=Trace+'D'; inherited Destroy; end;", "Trace:=Trace+'N'; raise TLocalError.Create;")})
    failure_host = out / 'failure-host'
    compile('failure-host', ROOT / 'tests/dynamic-packages/package_loader_failures.pas', 'program', ('democontracts',), failure_host)
    app = bundle(failure_host) / 'package_loader_failures'
    # A normal SO whose dependency exports FPC_PACKAGE_INFO must still be rejected.
    plain = fixtures / 'plain.c'
    plain.write_text('extern void *FPC_PACKAGE_NXRTL; void *reference(void) { return &FPC_PACKAGE_NXRTL; }\n')
    run('plain-library', ['gcc', '-shared', '-fPIC', plain, '-L' + str(bundle(providers)),
        '-lnxrtl', '-Wl,-rpath,$ORIGIN', '-o', fixtures / 'libplain.so'])
    for mode in ('init', 'new-dependency', 'live-dependency', 'cleanup', 'finalization', 'callback',
                 'tls', 'nested-load', 'nested-unload', 'non-exception', 'missing', 'not-package',
                 'duplicate', 'sdk', 'abi', 'dependency'):
        executable = runtime_copy(out / ('case-' + mode), app)
        case = executable.parent
        if mode == 'duplicate':
            shutil.copy2(case / 'libpluginleft.so', case / 'libduplicate.so')
        if mode in ('sdk', 'abi', 'dependency'):
            target = case / ('libpluginbase.so' if mode == 'dependency' else 'libbad.so')
            if mode != 'dependency':
                shutil.copy2(case / 'libpluginleft.so', target)
            alter(target, mode)
        command = [executable, mode]
        if mode == 'not-package':
            shutil.copy2(fixtures / 'libplain.so', case)
            command.append(case / 'libplain.so')
        run('failure-' + mode, command, marker='PASS ' + mode)

    current = providers / 'current.json'
    before = current.read_bytes()
    hashes = {p.name: digest(p) for p in bundle(providers).iterdir()}
    broken = fixtures / 'broken.ppk'
    broken.write_text('package broken; requires nxrtl; contains MissingUnit; end.\n')
    compile('broken', broken, expected=1, marker='Compilation failed')
    assert current.read_bytes() == before and hashes == {p.name: digest(p) for p in bundle(providers).iterdir()}
    record('failed-build-preserves-publication')
    (fixtures / 'BrokenLinkUnit.pas').write_text(unit('BrokenLinkUnit',
        "procedure MissingExternal; external name 'MissingPackageLinkSymbol';", 'MissingExternal;'))
    broken.write_text('package broken; requires nxrtl, democontracts; contains BrokenLinkUnit; end.\n')
    compile('broken-link', broken, expected=1, marker='Compilation failed')
    assert current.read_bytes() == before
    record('failed-link-preserves-publication')
    compile('stale-consumers', late / 'base/pluginbase.ppk', expected=1, marker='replacing an existing package')
    assert current.read_bytes() == before
    record('stale-consumers-preserve-publication')
    damaged = out / 'damaged-bundle'
    shutil.copytree(bundle(providers), damaged)
    path = damaged / 'libfailinit.so'
    path.write_bytes(path.read_bytes() + b'tampered')
    try:
        bundle(damaged)
    except ValueError as error:
        assert 'artifact differs' in str(error)
    else:
        raise AssertionError('Accepted damaged bundle')
    record('reject-damaged-bundle')
    mismatched = out / 'mismatched-pair'
    mismatched.mkdir()
    for path in bundle(providers).iterdir():
        if path.suffix in ('.pcp', '.so'):
            shutil.copy2(path, mismatched)
    alter(mismatched / 'libfailinit.so', 'dependency')
    pair_output = out / 'pair-output'
    pair_output.mkdir()
    try:
        publish(pair_output, mismatched, 'failinit', 'package', sdk_manifest['sdk_identity'], [mismatched])
    except ValueError as error:
        assert 'PCP and ELF identities differ' in str(error)
    else:
        raise AssertionError('Accepted mismatched PCP/ELF pair')
    assert not (pair_output / 'current.json').exists()
    record('reject-mismatched-pair')
    valid = bundle(providers) / 'libpluginleft.so'
    elf = ELF(valid)
    section_table = struct.unpack_from('<Q', elf.data, 40)[0]
    malformed = out / 'malformed.so'
    cases = []
    data = bytearray(elf.data)
    struct.pack_into('<H', data, 60, 65535)
    cases.append(('section-count', data, 'section layout'))
    symbols = next(i for i, section in enumerate(elf.sections) if section[1] == 11)
    data = bytearray(elf.data)
    struct.pack_into('<I', data, section_table + symbols * 64 + 40, 0xffffffff)
    cases.append(('symbol-link', data, 'symbol table'))
    relocation = next(section for section in elf.sections if section[1] == 4)
    data = bytearray(elf.data)
    struct.pack_into('<Q', data, relocation[4] + 8, 0xffffffff00000001)
    cases.append(('relocation-index', data, 'relocation symbol'))
    for name, data, message in cases:
        malformed.write_bytes(data)
        try:
            ELF(malformed).descriptor()
        except ValueError as error:
            assert message in str(error)
        else:
            raise AssertionError('Accepted malformed ELF: ' + name)
        record('reject-malformed-' + name)
    # The relocated SDK contains only the files advertised for distribution.
    relocated_sdk = out / 'relocated SDK'
    relocated_sdk.mkdir()
    for directory in ('bin', 'packages', 'units'):
        shutil.copytree(sdk / directory, relocated_sdk / directory)
    shutil.copy2(sdk / 'sdk.json', relocated_sdk)
    original_compiler, original_sdk = compiler, sdk
    sdk = relocated_sdk
    compiler = relocated_sdk / 'bin/compile_linux_package.py'
    relocated_host = out / 'relocated-build'
    compile('relocated-sdk', late / 'host/late_console.pas', 'program', ('democontracts',), relocated_host)
    run('relocated-sdk-runtime', [bundle(relocated_host) / 'late_console', out / 'relocated-sdk.log'],
        cwd=Path('/'), marker='PASS late package loading')
    for artifact in sdk_manifest['artifacts']:
        assert digest(relocated_sdk / artifact['path']) == artifact['sha256']
    record('relocated-sdk-unchanged')
    path = relocated_sdk / 'units/sysinitpkg.o'
    path.write_bytes(path.read_bytes() + b'tampered')
    compile('reject-damaged-sdk', late / 'host/late_console.pas', 'program', ('democontracts',),
            out / 'damaged-sdk-build', expected=1, marker='SDK artifact differs')
    assert not (out / 'damaged-sdk-build/current.json').exists()
    compiler, sdk = original_compiler, original_sdk
    for path in bundle(providers).glob('*.so'):
        dynamic = run('elf-' + path.stem, ['readelf', '-dW', path])
        assert 'TEXTREL' not in dynamic
    record('no-text-relocations')
    print(f'PASS {len(steps)} Linux package checks. Logs: {out}', flush=True)


def alter(path, kind):
    elf = ELF(path)
    descriptor = elf.pointer(elf.symbols['FPC_PACKAGE_INFO'])
    data = bytearray(path.read_bytes())
    if kind == 'abi':
        struct.pack_into('<Q', data, elf.offset(descriptor) + 8, 999)
    else:
        address = elf.pointer(descriptor + 8 * (18 if kind == 'sdk' else 19))
        offset = elf.offset(address)
        data[offset + 1:offset + 1 + data[offset]] = b'E' * data[offset]
    path.write_bytes(data)


if __name__ == '__main__':
    main()
