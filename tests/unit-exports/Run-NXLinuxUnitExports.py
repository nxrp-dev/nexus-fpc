# Copyright (c) 2026 Kevin Collins.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses",
# as defined by the Mozilla Public License, v. 2.0.
#
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
"""Linux unit export regression; supports a Windows cross compiler under WSL."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--compiler', required=True)
parser.add_argument('--rtl', required=True, type=Path)
parser.add_argument('--assembler-dir')
parser.add_argument('--output', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parent
output = args.output or Path(tempfile.mkdtemp(prefix='nx-linux-exports-'))
if args.output:
    output.mkdir()  # Refuse stale outputs.
output = output.resolve()
cross = args.compiler.lower().endswith('.exe')
steps = []


def compiler_path(path):
    path = str(Path(path).resolve())
    if cross:
        match = re.fullmatch(r'/mnt/([a-z])/(.*)', path)
        if not match:
            raise ValueError('Windows cross compiler requires paths beneath /mnt/<drive>')
        return match[1].upper() + ':/' + match[2]
    return path


def run(name, command, cwd, expected=0):
    result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log = output / (name + '.log')
    log.write_bytes(result.stdout)
    steps.append(dict(step=name, command=list(map(str, command)), exit_code=result.returncode,
                      expected_exit_code=expected, log=str(log)))
    (output / 'steps.json').write_text(json.dumps(steps, indent=2))
    if result.returncode != expected:
        raise RuntimeError(f'{name} failed ({result.returncode}): {log}\n'
                           + result.stdout.decode(errors='replace'))
    print('PASS', name, flush=True)
    return result.stdout.decode(errors='replace')


def unit_hashes(case):
    return {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in case.glob('utNXLinuxExports.*') if path.suffix in ('.ppu', '.o', '.a')}


for mode in ('normal', 'smart'):
    case = output / mode
    case.mkdir()
    for name in ('utNXLinuxExports.pas', 'nxLinuxExports.lpr', 'nxLinuxExportsLibrary.lpr'):
        shutil.copy2(root / name, case / name)
    common = [args.compiler, '-n', '-Tlinux', '-Cn', '-XP', '-O2', '-Cg', '-Cr', '-Co', '-Ci',
              '-Fu' + compiler_path(args.rtl), '-Fu' + compiler_path(case),
              '-FU' + compiler_path(case), '-FE' + compiler_path(case)]
    if args.assembler_dir:
        common += ['-FD' + args.assembler_dir]
    if mode == 'smart':
        common += ['-CX', '-XX']
    run(mode + '-standalone-unit', common + ['-B', 'utNXLinuxExports.pas'], case)
    for kind in ('library', 'program'):
        source = 'nxLinuxExportsLibrary.lpr' if kind == 'library' else 'nxLinuxExports.lpr'
        states = ('cold', 'cached') if kind == 'library' else ('standalone', 'cold', 'cached')
        for state in states:
            name = mode + '-' + kind + '-' + state
            before = unit_hashes(case)
            hidden = case / 'utNXLinuxExports.pas.hidden'
            unit_source = case / 'utNXLinuxExports.pas'
            if state != 'cold':
                unit_source.rename(hidden)
            try:
                run(name + '-compile', common + (['-B'] if state == 'cold' else []) + [source], case)
            finally:
                if state != 'cold':
                    hidden.rename(unit_source)
            if state != 'cold' and unit_hashes(case) != before:
                raise RuntimeError('Cached unit object or PPU changed')
            response = max(case.glob('link*.res'), key=lambda path: path.stat().st_mtime_ns)
            script = response.read_text()
            if cross:
                script = re.sub(r'([A-Za-z]):[\\/]', lambda m: '/mnt/' + m[1].lower() + '/', script)
                script = script.replace('\\', '/')
            converted = case / 'linux-link.res'
            converted.write_text(script)
            image = case / ('libnxLinuxExportsLibrary.so' if kind == 'library' else 'nxLinuxExports')
            linker = ['ld', '-b', 'elf64-x86-64', '-m', 'elf_x86_64', '-z', 'noexecstack',
                      '-T', str(converted), '-o', str(image)]
            if kind == 'library':
                linker += ['-shared', '-init', 'FPC_SHARED_LIB_START', '-fini', 'FPC_LIB_EXIT',
                           '-soname', image.name]
            else:
                linker += ['-e', '_start', '-E']
            if mode == 'smart':
                linker += ['--gc-sections']
            run(name + '-link', linker, case)
            symbols = run(name + '-symbols', ['nm', '-D' if kind == 'library' else '-g',
                                             '--defined-only', str(image)], case)
            for symbol in ('NX_LinuxMarker', 'NX_LinuxAutomatic', 'NX_LinuxData', 'NX_LinuxMain', 'PlainMarker', 'UTNXLINUXEXPORTS_$$_PLAINMARKER$$LONGINT'):
                if not re.search(r'\b' + re.escape(symbol) + r'$', symbols, re.MULTILINE):
                    raise RuntimeError(name + ' missing ' + symbol)
            if mode == 'smart':
                all_symbols = run(name + '-all-symbols', ['nm', '--defined-only', str(image)], case)
                if re.search(re.escape('UTNXLINUXEXPORTS_$$_DISCARDMARKER$$LONGINT') + r'$', all_symbols, re.MULTILINE):
                    raise RuntimeError('Unused non-exported routine retained')
            if kind == 'program':
                run(name + '-runtime', [str(image)], case)
            else:
                # A separate process forces each library to be loaded afresh.
                run(name + '-runtime', ['python3', '-c',
                    "import ctypes,sys; lib=ctypes.CDLL(sys.argv[1]); "
                    "lib.NX_LinuxMarker.argtypes=[ctypes.c_int32]; "
                    "lib.NX_LinuxMarker.restype=ctypes.c_int32; "
                    "assert lib.NX_LinuxMarker(5)==47; "
                    "assert lib.NX_LinuxAutomatic()==77; assert lib.NX_LinuxMain()==99; "
                    "assert lib.PlainMarker()==55; "
                    "assert getattr(lib,'UTNXLINUXEXPORTS_$$_PLAINMARKER$$LONGINT')()==55; "
                    "v=ctypes.c_int32.in_dll(lib,'NX_LinuxData'); assert v.value==1234; "
                    "v.value=4321; assert v.value==4321; print('PASS dynamic C ABI exports')", str(image)], case)
# Diagnostics must still reject conflicting names and unsupported ordinals.
case = output / 'diagnostics'
case.mkdir()
shutil.copy2(root / 'utNXLinuxExports.pas', case / 'utNXLinuxExports.pas')
common = [args.compiler, '-n', '-Tlinux', '-Cn', '-XP', '-Cg',
          '-Fu' + compiler_path(args.rtl), '-Fu' + compiler_path(case),
          '-FU' + compiler_path(case), '-FE' + compiler_path(case)]
if args.assembler_dir:
    common += ['-FD' + args.assembler_dir]
(case / 'duplicate.lpr').write_text("library duplicate; {$mode objfpc} uses utNXLinuxExports; "
    "function Clash: LongInt; cdecl; begin Result:=0; end; "
    "exports Clash name 'NX_LinuxMarker'; begin end.")
for state in ('cold', 'cached'):
    text = run('duplicate-' + state, common + (['-B'] if state == 'cold' else []) + ['duplicate.lpr'], case, 1)
    if 'Duplicate exported function name "NX_LinuxMarker"' not in text:
        raise RuntimeError('Missing duplicate-name diagnostic')
(case / 'ordinal.pas').write_text("unit ordinal; {$mode objfpc} interface implementation "
    "function Marker: LongInt; cdecl; begin Result:=0; end; exports Marker index 7; end.")
text = run('unsupported-ordinal', common + ['ordinal.pas'], case, 1)
if 'Cannot export with index under' not in text:
    raise RuntimeError('Missing unsupported-ordinal diagnostic')
print('PASS Linux unit exports:', output)
