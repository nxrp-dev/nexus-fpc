"""Build and validate the experimental Win64 shared RTL in isolated directories."""
import argparse
import ctypes
import hashlib
import re
import sys
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def inspect(directory):
    class Descriptor(ctypes.Structure):
        _fields_ = [(name, ctypes.c_size_t) for name in (
            'magic', 'version', 'size', 'compiler', 'target', 'rtl', 'name', 'unit_count', 'units',
            'dependency_count', 'dependencies', 'init_final', 'threadvars', 'resources',
            'wide', 'resrefs', 'context', 'handle', 'sdk_identity', 'build_identity', 'dependency_ids')]

    def short(address):
        count = ctypes.c_ubyte.from_address(address).value
        return ctypes.string_at(address + 1, count).decode('ascii')

    records = []
    libraries = []
    identities = set()
    for name in ('nxrtl', 'pkgshared', 'pkgleft', 'pkgright', 'pkgfail'):
        library = ctypes.CDLL(str(directory / (name + '.dll')))
        libraries.append(library)
        descriptor = Descriptor.in_dll(library, 'FPC_PACKAGE_' + name.upper())
        assert descriptor.magic == 0x4e58504b and descriptor.version == 4
        assert descriptor.compiler == (208 << 48) | (0xc181 << 32) | 34
        assert descriptor.size == ctypes.sizeof(Descriptor) == 168
        assert descriptor.rtl != 0
        identities.add((descriptor.compiler, descriptor.target, descriptor.rtl))
        assert short(descriptor.name) == name.upper()
        context = (ctypes.c_size_t * 6).from_address(descriptor.context)
        assert list(context) == [0] * 6, 'descriptor inspection initialized a module'
        assert ctypes.c_size_t.from_address(descriptor.handle).value == library._handle
        units = [short(x) for x in (ctypes.c_size_t * descriptor.unit_count).from_address(descriptor.units)]
        dependencies = []
        for slot in (ctypes.c_size_t * descriptor.dependency_count).from_address(descriptor.dependencies):
            target = Descriptor.from_address(ctypes.c_size_t.from_address(slot).value)
            dependencies.append(short(target.name))
        if name == 'pkgshared':
            assert sorted(units) == ['UPACKAGERUNTIME', 'UUNUSED']
            routine = library.NX_RuntimeInitializations
            routine.restype = ctypes.c_int32
            assert routine() == 0, 'native loading initialized Pascal units'
        if name in ('pkgleft', 'pkgright'):
            assert set(dependencies) == {'NXRTL', 'PKGSHARED'}, dependencies
        records.append(dict(name=name, units=units, dependencies=dependencies, initialized=False))
    assert len(identities) == 1, 'packages disagree about the compiler, target or RTL'
    (directory / 'descriptors.json').write_text(json.dumps(records, indent=2))
    print('PASS descriptor inspection without activation')


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--output-root', type=Path)
    parser.add_argument('--inspect', type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.inspect:
        inspect(args.inspect.resolve())
        return
    root = Path(__file__).resolve().parents[2]
    out = (args.output_root or Path(tempfile.mkdtemp(prefix='nxpkg-runtime-'))).resolve()
    out.mkdir(exist_ok=True, parents=True)
    steps = []

    def run(name, cmd, cwd=out):
        log = out / (name + '.log')
        with log.open('w') as f:
            p = subprocess.run([str(x) for x in cmd], cwd=cwd, stdout=f,
                               stderr=subprocess.STDOUT, timeout=600)
        steps.append(dict(name=name, exit_code=p.returncode, command=[str(x) for x in cmd], log=str(log)))
        (out / 'steps.json').write_text(json.dumps(steps, indent=2))
        if p.returncode:
            raise RuntimeError(f'{name}: exit {p.returncode}; details: {log}')
        print('PASS', name, flush=True)
        return log.read_text(errors='replace')

    build = out / 'compiler'
    units = build / 'units'
    units.mkdir(parents=True, exist_ok=True)
    bootstrap = Path(r'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\ppcx64.exe')
    opts = ['-n', '-O1', '-dx86_64', f'-Fu{bootstrap.parents[2] / "units/x86_64-win64/rtl"}',
            f'-Fu{units}', f'-FU{units}', f'-FE{build}']
    for part in ('', 'x86_64', 'x86', 'systems'):
        opts += [f'-Fu{root / "compiler" / part}', f'-Fi{root / "compiler" / part}']
    run('compiler', [bootstrap, *opts, '-oppcx64.exe', root / 'compiler/pp.pas'])
    run('driver', [bootstrap, *opts, root / 'tests/dynamic-packages/package_compiler.pas'])
    driver = build / 'package_compiler.exe'
    rtl = out / 'rtl-packaged'
    rtl.mkdir(exist_ok=True)
    rtl_bin = out / 'rtl-bin'
    rtl_bin.mkdir(exist_ok=True)
    run('rtl', [bootstrap.parent / 'make.exe', '-s', '-C', root / 'rtl/win64', 'all',
                f'FPC={driver.as_posix()}', 'CPU_TARGET=x86_64', 'OS_TARGET=win64',
                f'COMPILER_UNITTARGETDIR={rtl.as_posix()}', f'COMPILER_TARGETDIR={rtl_bin.as_posix()}',
                'OPT=-n'])
    readobj = shutil.which('llvm-readobj.exe')
    if not readobj:
        raise RuntimeError('LLVM tools must be on PATH')
    llvm = Path(readobj).parent
    common = ['-n', '-Mobjfpc', f'-Fu{rtl}', f'-FD{llvm}']
    lifecycle = out / 'lifecycle'
    lifecycle.mkdir(exist_ok=True)
    run('lifecycle-build', [driver, *common, f'-Fu{root / "rtl/inc"}', f'-FU{lifecycle}', f'-FE{lifecycle}',
                            root / 'tests/dynamic-packages/package_lifecycle_test.pas'])
    run('lifecycle-run', [lifecycle / 'package_lifecycle_test.exe'])

    for smart in (False, True):
        for cached in (False, True):
            case_name = ('smart' if smart else 'normal') + ('-cached' if cached else '-fresh')
            case = out / case_name
            distribution = case / 'distribution'
            distribution.mkdir(parents=True, exist_ok=True)
            package_opts = common + (['-CX', '-XX'] if smart else [])
            searches = [f'-Fp{distribution}', f'-Fl{distribution}']

            def package(name, requires, contents):
                directory = case / name
                directory.mkdir(exist_ok=True)
                for unit, text in contents.items():
                    (directory / (unit + '.pas')).write_text(text)
                command = [driver, *package_opts, *searches, f'-Fu{directory}', f'-Fi{root / "rtl/inc"}',
                           f'-FU{directory}', f'-FE{directory}']
                snapshots = {}
                if cached:
                    for unit in contents:
                        run(case_name + '-' + name + '-' + unit, command +
                            ['-FP' + requirement for requirement in requires] + [directory / (unit + '.pas')])
                    for unit in contents:
                        snapshots[unit] = [hashlib.sha256((directory / (unit + ext)).read_bytes()).hexdigest()
                                           for ext in ('.ppu', '.o')]
                        (directory / (unit + '.pas')).replace(directory / (unit + '.pas.hidden'))
                declaration = 'package ' + name + '; '
                if requires:
                    declaration += 'requires ' + ', '.join(requires) + '; '
                declaration += 'contains ' + ', '.join(contents) + '; end.\n'
                source = directory / (name + '.ppk')
                source.write_text(declaration)
                run(case_name + '-' + name, command + [source])
                for unit, before in snapshots.items():
                    after = [hashlib.sha256((directory / (unit + ext)).read_bytes()).hexdigest()
                             for ext in ('.ppu', '.o')]
                    assert before == after, f'{unit}: cached artifacts changed'
                for ext in ('.pcp', '.dll'):
                    shutil.copy2(directory / (name + ext), distribution)
                # Make even absolute paths to original units unusable.
                for unit in contents:
                    for ext in ('.pas', '.ppu', '.o'):
                        original = directory / (unit + ext)
                        if original.exists():
                            hidden = original.with_suffix(ext + '.hidden')
                            if hidden.exists(): hidden.unlink()
                            original.rename(hidden)

            package('nxrtl', [], {'fpcpackage': (root / 'rtl/inc/fpcpackage.pp').read_text()})
            unused = """unit uunused;
{$mode objfpc}{$H+}
interface
implementation
uses upackageruntime;
threadvar Value: LongInt;
const UnusedWide: WideString = 'unused owner';
initialization
  Value:=71;
  UnusedReady:=(Value=71) and (UnusedWide='unused owner');
  Trace:=Trace+'U';
finalization
  WriteLn('FINAL U'); Flush(Output);
end.
"""
            package('pkgshared', ['nxrtl'], {
                'upackageruntime': (root / 'tests/dynamic-packages/upackageruntime.pas').read_text(),
                'uunused': unused})
            for name, letter in [('left', 'L'), ('right', 'R')]:
                code = (f"unit u{name}; interface implementation uses upackageruntime; "
                        f"initialization Trace:=Trace+'{letter}'; finalization WriteLn('FINAL {letter}'); Flush(Output); end.\n")
                package('pkg' + name, ['nxrtl', 'pkgshared'], {'u' + name: code})
            package('pkgfail', ['nxrtl', 'pkgshared'], {
                'ufailfirst': "unit ufailfirst; interface implementation uses upackageruntime; "
                    "initialization Trace:=Trace+'F'; finalization Trace:=Trace+'f'; end.\n",
                'ufailsecond': "unit ufailsecond; interface implementation uses ufailfirst, upackageruntime; "
                    "initialization Trace:=Trace+'!'; raise EPackageProbe.Create('initialization failure'); end.\n"})
            exports = {}
            for dll in sorted(distribution.glob('*.dll')):
                output = run(case_name + '-' + dll.stem + '-exports', [readobj, '--coff-exports', dll])
                exports[dll.name.lower()] = set(re.findall(r'^\s*Name: (.+)$', output, re.MULTILINE))

            def check_imports(image):
                output = run(case_name + '-' + image.stem + '-imports', [readobj, '--coff-imports', image])
                for block in re.findall(r'Import \{(.*?)\n\}', output, re.DOTALL):
                    owner = re.search(r'Name: (.+)', block).group(1).strip().lower()
                    if owner in exports:
                        imported = set(re.findall(r'^\s*Symbol: (.+) \(\d+\)$', block, re.MULTILINE))
                        assert imported <= exports[owner], f'{image.name}: missing exports from {owner}: {imported - exports[owner]}'

            for dll in sorted(distribution.glob('*.dll')):
                check_imports(dll)
            run(case_name + '-inspect', [sys.executable, Path(__file__).resolve(), '--inspect', distribution])
            host = case / 'host'
            host.mkdir(exist_ok=True)
            imports = [*searches, '-FPnxrtl', '-FPpkgshared', '-FPpkgleft', '-FPpkgright']
            run(case_name + '-startup', [driver, *package_opts, *imports, f'-FU{host}',
                                         root / 'rtl/win64/sysinitpkg.pp'])
            (host / 'uhost.pas').write_text("unit uhost; interface implementation uses upackageruntime; "
                "initialization Trace:=Trace+'H'; finalization WriteLn('FINAL H'); Flush(Output); end.\n")
            run(case_name + '-host-build', [driver, *package_opts, *imports, f'-Fu{host}', f'-FU{host}', f'-FE{host}',
                                            root / 'tests/dynamic-packages/package_runtime_host.pas'])
            check_imports(host / 'package_runtime_host.exe')
            for dll in distribution.glob('*.dll'): shutil.copy2(dll, host)
            run(case_name + '-host-run', [host / 'package_runtime_host.exe'], cwd=host)
            output = (out / (case_name + '-host-run.log')).read_text().splitlines()
            assert output == ['PASS shared RTL: identity, allocation, managed values, exception, resources',
                              'FINAL H', 'FINAL R', 'FINAL L', 'FINAL U', 'FINAL A'], output
            for unit in ('fpcpackage', 'upackageruntime', 'uunused', 'uleft', 'uright'):
                assert not (host / (unit + '.ppu')).exists(), f'{unit}: leaked standalone PPU'
    print('PASS runtime suite:', out)


if __name__ == '__main__':
    main()
