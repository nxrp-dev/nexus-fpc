"""Experimental Win64 package linking and symbol checks, using one process at a time."""

import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def probe(directory):
    # Run in a separate process so each case starts with fresh DLL data. No Pascal
    # initialization, heap allocation, exceptions, or package lifecycle is assumed.
    base = ctypes.CDLL(str(directory / 'pkgbase.dll'))
    consumer = ctypes.CDLL(str(directory / 'pkgconsumer.dll'))

    def function(library, name, result=ctypes.c_void_p, arguments=()):
        value = getattr(library, name)
        value.restype = result
        value.argtypes = arguments
        return value

    for name in ('Counter', 'Class', 'RTTI', 'EnumRTTI', 'RecordRTTI', 'Resource'):
        expected = function(base, 'NX_Base' + name)()
        actual = function(consumer, 'NX_Consumer' + name)()
        assert expected and expected == actual, f'{name} identity differs'
        print('PASS shared', name, flush=True)

    address = function(base, 'NX_BaseCounter')()
    assert function(consumer, 'NX_ConsumerAlias')() == address
    counter = ctypes.c_int32.from_address(address)
    assert counter.value == 7
    add = function(consumer, 'NX_ConsumerAdd', ctypes.c_int32, (ctypes.c_int32,))
    assert add(5) == 12 and counter.value == 12
    counter.value = 30
    assert add(2) == 32 and counter.value == 32
    # Imported procedure addresses can be local thunks; both must call the same
    # provider function and update its one counter.
    for library, name in ((base, 'NX_BaseProc'), (consumer, 'NX_ConsumerProc')):
        routine = ctypes.CFUNCTYPE(ctypes.c_int32, ctypes.c_int32)(function(library, name)())
        assert routine(1) == counter.value
    assert counter.value == 34
    assert function(consumer, 'NX_ConsumerParent')() == function(base, 'NX_BaseClass')()
    for name, expected in (('Inherits', 1), ('Virtual', 133), ('Managed', 1), ('Inline', 1017)):
        assert function(consumer, 'NX_Consumer' + name, ctypes.c_int32)() == expected, name
        print('PASS', name, flush=True)
    print('PASS runtime symbols', flush=True)


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--source-root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--compiler-build', type=Path)
    parser.add_argument('--bootstrap', type=Path,
                        default=Path(r'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\ppcx64.exe'))
    parser.add_argument('--output-root', type=Path)
    parser.add_argument('--probe', type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.probe:
        probe(args.probe.resolve())
        return
    source = args.source_root.resolve()
    fixtures = source / 'tests' / 'dynamic-packages'
    out = (args.output_root or Path(tempfile.mkdtemp(prefix='nxpkg-link-'))).resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise RuntimeError('Output directory must be empty')
    readobj = shutil.which('llvm-readobj.exe')
    if not readobj:
        raise RuntimeError('LLVM tools must be on PATH')
    tool_directory = Path(readobj).parent
    steps = []

    def run(name, command, cwd=out, expected=0, text=None):
        command = [str(x) for x in command]
        log = out / (name + '.log')
        with log.open('w', encoding='utf-8') as stream:
            result = subprocess.run(command, cwd=cwd, stdout=stream,
                                    stderr=subprocess.STDOUT, timeout=600)
        output = log.read_text(encoding='utf-8', errors='replace')
        steps.append(dict(name=name, command=command, cwd=str(cwd),
                          exit_code=result.returncode, expected=expected, log=str(log)))
        (out / 'steps.json').write_text(json.dumps(steps, indent=2), encoding='utf-8')
        if result.returncode != expected or (text and text not in output):
            raise RuntimeError(f'{name}: exit {result.returncode}, expected {expected}; '
                               f'expected text {text!r}\n{output[-6000:]}\nLog: {log}')
        print('PASS', name, flush=True)
        return output

    metadata = out / 'metadata'
    command = [sys.executable, fixtures / 'run_package_metadata_tests.py',
               '--source-root', source, '--bootstrap', args.bootstrap, '--output-root', metadata]
    if args.compiler_build:
        command += ['--compiler-build', args.compiler_build.resolve()]
    run('metadata-suite', command)
    build = args.compiler_build.resolve() if args.compiler_build else metadata / 'compiler'
    driver = build / 'package_metadata_test.exe'
    rtl = source / 'rtl' / 'units' / 'x86_64-win64'

    for smart in (False, True):
        for cached in (False, True):
            name = ('smart' if smart else 'normal') + ('-cached' if cached else '-fresh')
            case = out / name
            provider = case / 'provider'
            consumer = case / 'consumer'
            distribution = case / 'distribution'
            for directory in (provider, consumer, distribution):
                directory.mkdir(parents=True)

            def compile(label, directory, filename, packages=False, expected=0, text=None):
                options = ['-n', '-Mobjfpc', f'-Fu{rtl}', f'-FU{directory}',
                           f'-FE{directory}', f'-FD{tool_directory}']
                if smart:
                    options += ['-CX', '-XX']
                if packages:
                    options += [f'-Fp{distribution}', f'-Fl{distribution}']
                (directory / 'build.rsp').write_text('\n'.join(options))
                return run(name + '-' + label,
                           [driver, 'compile', '-n @build.rsp ' + filename], cwd=directory,
                           expected=expected, text=text)

            def hashes(directory, unit):
                return [hashlib.sha256((directory / (unit + suffix)).read_bytes()).hexdigest()
                        for suffix in ('.ppu', '.o')]

            shutil.copy2(fixtures / 'upackagebase.pas', provider)
            (provider / 'pkgbase.ppk').write_text('package pkgbase; contains upackagebase; end.\n')
            if cached:
                compile('base-unit', provider, 'upackagebase.pas')
                before = hashes(provider, 'upackagebase')
                (provider / 'upackagebase.pas').rename(provider / 'upackagebase.pas.hidden')
            compile('base-package', provider, 'pkgbase.ppk')
            if cached:
                assert before == hashes(provider, 'upackagebase'), 'base cached artifacts changed'
            for suffix in ('.pcp', '.dll'):
                shutil.copy2(provider / ('pkgbase' + suffix), distribution)
            # Remove even absolute-path access to the provider unit's original
            # files, so the consumer must use the distributed PCP and DLL.
            for suffix in ('.pas', '.ppu', '.o'):
                original = provider / ('upackagebase' + suffix)
                if original.exists():
                    original.rename(original.with_suffix(suffix + '.hidden'))

            shutil.copy2(fixtures / 'upackageconsumer.pas', consumer)
            (consumer / 'pkgconsumer.ppk').write_text(
                'package pkgconsumer; requires pkgbase; contains upackageconsumer; end.\n')
            if cached:
                # Unit compilation gets package references from the command line;
                # the package declaration itself obtains them from requires.
                options = ['-n', '-Mobjfpc', f'-Fu{rtl}', f'-FU{consumer}', f'-FE{consumer}',
                           f'-FD{tool_directory}', f'-Fp{distribution}', f'-Fl{distribution}',
                           '-FPpkgbase'] + (['-CX', '-XX'] if smart else [])
                (consumer / 'unit.rsp').write_text('\n'.join(options))
                run(name + '-consumer-unit',
                    [driver, 'compile', '-n @unit.rsp upackageconsumer.pas'], cwd=consumer)
                before = hashes(consumer, 'upackageconsumer')
                (consumer / 'upackageconsumer.pas').rename(consumer / 'upackageconsumer.pas.hidden')
            compile('consumer-package', consumer, 'pkgconsumer.ppk', packages=True)
            if cached:
                assert before == hashes(consumer, 'upackageconsumer'), 'consumer cached artifacts changed'
            assert not (consumer / 'upackagebase.ppu').exists()
            for suffix in ('.pcp', '.dll'):
                shutil.copy2(consumer / ('pkgconsumer' + suffix), distribution)

            exports = run(name + '-exports', [readobj, '--coff-exports', distribution / 'pkgbase.dll'])
            imports = run(name + '-imports', [readobj, '--coff-imports', distribution / 'pkgconsumer.dll'])
            exported = set(re.findall(r'^\s*Name: (.+)$', exports, re.MULTILINE))
            assert 'NX_BaseCounter' in exported, 'missing public procedure alias'
            # All imports in this fixture belong to the required package.
            assert 'Name: pkgbase.dll' in imports
            imported = set(re.findall(r'^\s*Symbol: (.+) \(\d+\)$', imports, re.MULTILINE))
            assert imported and imported <= exported, f'unexported imports: {imported - exported}'
            for symbol in ('VMT_$UPACKAGEBASE_$$_TPACKAGECLASS',
                           'RTTI_$UPACKAGEBASE_$$_TPACKAGECLASS',
                           'RTTI_$UPACKAGEBASE_$$_TPACKAGEENUM',
                           'RTTI_$UPACKAGEBASE_$$_TPACKAGERECORD',
                           'INIT_$UPACKAGEBASE_$$_TPACKAGERECORD',
                           'fpc_initialize', 'fpc_finalize', '__FPC_specific_handler',
                           'RESSTR_$UPACKAGEBASE_$$_PACKAGETEXT',
                           'UPACKAGEBASE_$$_BASECOUNTER$$POINTER',
                           'UPACKAGEBASE_$$_HIDDENHELPER$LONGINT$$LONGINT',
                           'UPACKAGEBASE_$$_ADD$LONGINT$$LONGINT'):
                assert symbol in imported, f'missing import {symbol}'
            run(name + '-runtime', [sys.executable, __file__, '--probe', distribution],
                text='PASS runtime symbols')

            if not smart and not cached:
                for filename, content, diagnostic in (
                    ('empty.ppk', 'package empty; end.', 'does not contain or require the System unit'),
                    ('missing.ppk', 'package missing; contains no_such_unit;', "Can't find unit"),
                    ('duplicate.ppk', 'package duplicate; requires pkgbase; contains upackagebase; end.',
                     'is already contained in package pkgbase'),
                ):
                    (consumer / filename).write_text(content + '\n')
                    compile(filename[:-4], consumer, filename, packages=True,
                            expected=1, text=diagnostic)

                # Shared RTL EXE startup is covered by run_package_runtime_tests.py.
    print(f'PASS {len(steps)} link-suite steps. Results: {out}', flush=True)


if __name__ == '__main__':
    main()
