"""Win64 artifact family isolation, revision boundaries and standalone utilities."""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--sdk', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--source-root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--bootstrap', type=Path,
                        default=Path(r'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\ppcx64.exe'))
    args = parser.parse_args()
    root, sdk, out = args.source_root.resolve(), args.sdk.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise RuntimeError('Output directory must be empty')
    steps = []

    def record(name):
        steps.append(dict(name=name, passed=True))
        (out / 'steps.json').write_text(json.dumps(steps, indent=2))
        print('PASS', name, flush=True)

    def run(name, command, expected=0, text=None, cwd=out):
        command = [str(x) for x in command]
        result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=600)
        output = result.stdout.decode('utf-8', errors='replace')
        log = out / (name + '.log')
        log.write_text(output, encoding='utf-8')
        if result.returncode != expected or (text and text not in output):
            raise RuntimeError(f'{name}: exit {result.returncode}, expected {expected}, '
                               f'text {text!r}; {log}\n{output[-4000:]}')
        if 'Internal error' in output or 'Access violation' in output:
            raise RuntimeError(f'Compiler crashed: {log}')
        record(name)
        return output

    bootstrap_rtl = args.bootstrap.parents[2] / 'units/x86_64-win64/rtl'
    candidate = sdk / 'bin/ppcx64.exe'
    rtl = sdk / 'work/rtl-units'
    build = out / 'tools'
    build.mkdir()
    options = ['-n', f'-Fu{bootstrap_rtl}', f'-FU{build}', f'-FE{build}',
               f'-Fu{root / "compiler"}', f'-Fi{root / "compiler"}',
               f'-Fu{root / "compiler/generic"}', f'-Fu{root / "compiler/llvm"}',
               '-dGENERIC_CPU']
    for tool in ('ppufiles', 'ppumove'):
        run('build-' + tool, [args.bootstrap, *options, root / 'compiler/utils' / (tool + '.pp')])
    run('build-encoding', [args.bootstrap, *options,
                          root / 'tests/artifact-identity/identity_encoding.pas'])
    run('encoding-boundaries', [build / 'identity_encoding.exe'], text='PASS independent identity fields')

    source = out / 'source'
    source.mkdir()
    unit = source / 'uartifact.pas'
    unit_text = ('unit uartifact; {$mode objfpc} interface function Marker: LongInt; '
                 'implementation function Marker: LongInt; begin Result:=37; end; end.\n')
    unit.write_text(unit_text)
    host = source / 'host.pas'
    host.write_text('program host; uses uartifact; begin if Marker<>37 then Halt(1); end.\n')
    generated = {}
    for family, compiler, units in (('upstream', args.bootstrap, bootstrap_rtl),
                                    ('nexus', candidate, rtl)):
        directory = out / family
        directory.mkdir()
        run('build-' + family, [compiler, '-n', f'-Fu{units}', f'-FU{directory}', unit])
        generated[family] = (directory / 'uartifact.ppu').read_bytes()
    assert generated['upstream'][:3] == b'PPU'
    assert generated['nexus'][:6] == b'NXU208'
    unit.unlink()  # The reader must use the supplied artifact, not source fallback.

    def consume(label, data, upstream=False, expected=1, text='expected NexusFPC NXU'):
        directory = out / label
        directory.mkdir()
        (directory / 'uartifact.ppu').write_bytes(data)
        shutil.copy2(out / ('upstream' if upstream else 'nexus') / 'uartifact.o', directory)
        compiler, units = (args.bootstrap, bootstrap_rtl) if upstream else (candidate, rtl)
        run(label, [compiler, '-n', f'-Fu{units}', f'-Fu{directory}', f'-FU{directory}',
                    f'-FE{directory}', host], expected, text)
        return directory

    positive = consume('nexus-roundtrip', generated['nexus'], expected=0, text=None)
    run('execute-roundtrip', [positive / 'host.exe'])
    consume('upstream-unit-rejected', generated['upstream'])
    legacy = b'PPU' + generated['nexus'][3:]
    consume('same-version-foreign-family-rejected', legacy)
    corrupt = bytearray(legacy)
    struct.pack_into('<HH', corrupt, 8, 65535, 65535)
    consume('foreign-family-before-target-fields', corrupt)
    consume('upstream-rejects-nexus', generated['nexus'], upstream=True, text="Can't find unit")
    matched = bytearray(generated['nexus'])
    matched[3:6] = generated['upstream'][3:6]
    consume('upstream-rejects-nexus-at-own-version', matched, upstream=True, text="Can't find unit")
    bad_header = bytearray(generated['nexus'])
    bad_header[3:6] = b'209'
    consume('nexus-header-revision-rejected', bad_header, text='Version')
    bad_long = bytearray(generated['nexus'])
    assert bad_long[45] == 242  # Fixed header + entry header: ibextraheader.
    struct.pack_into('<I', bad_long, 46, 256)
    consume('nexus-long-revision-rejected', bad_long, text='Version')
    assert struct.unpack_from('<I', generated['nexus'], 46)[0] == 35
    struct.pack_into('<I', bad_long, 46, 34)
    consume('pre-standard-package-units-rejected', bad_long, text='Version')

    fallback = out / 'source-fallback'
    fallback.mkdir()
    (fallback / 'uartifact.ppu').write_bytes(legacy)
    (fallback / 'uartifact.pas').write_text(unit_text)
    run('source-fallback', [candidate, '-n', f'-Fu{rtl}', f'-Fu{fallback}',
                            f'-FU{fallback}', f'-FE{fallback}', host])
    assert (fallback / 'uartifact.ppu').read_bytes()[:6] == b'NXU208'
    run('execute-source-fallback', [fallback / 'host.exe'])

    run('ppufiles-valid', [build / 'ppufiles.exe', out / 'nexus/uartifact.ppu'], text='uartifact.o')
    for label, data, diagnostic in (
            ('foreign', legacy, 'NXU'), ('header', bad_header, 'Version'),
            ('long', bad_long, 'Long Version')):
        for tool in ('ppufiles', 'ppumove'):
            directory = out / (tool + '-' + label)
            directory.mkdir()
            fixture = directory / 'uartifact.ppu'
            fixture.write_bytes(data)
            command = [build / (tool + '.exe')]
            if tool == 'ppumove':
                command += ['-b', '-i' + str(directory), '-oartifact.dll']
            run(tool + '-' + label, [*command, fixture], expected=1,
                text=diagnostic, cwd=directory)
            assert fixture.read_bytes() == data
            if tool == 'ppumove':
                assert not (directory / 'pmove.bat').read_text().strip(), 'Rejected unit reached linker'
    moved = out / 'move-valid'
    moved.mkdir()
    for name in ('uartifact.ppu', 'uartifact.o'):
        shutil.copy2(out / 'nexus' / name, moved)
    run('ppumove-valid', [build / 'ppumove.exe', '-b', '-i' + str(moved),
                          '-oartifact.dll', 'uartifact.ppu'], cwd=moved)
    assert (moved / 'uartifact.ppu').read_bytes()[:6] == b'NXU208'
    assert (moved / 'pmove.bat').read_text().strip()

    spec = importlib.util.spec_from_file_location('artifacts', root / 'scripts/linux_package_artifacts.py')
    module = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(module)
    metadata = sdk / 'packages/nxrtl.pcp'
    assert metadata.read_bytes()[:6] == b'NXP004'
    assert module.metadata(metadata)['name'] == 'NXRTL'
    record('python-validator-nexus')
    foreign = out / 'foreign.pcp'
    foreign.write_bytes(b'PCP' + metadata.read_bytes()[3:])
    try:
        module.metadata(foreign)
    except ValueError as error:
        assert 'expected NexusFPC NXP004' in str(error)
    else:
        raise AssertionError('Python validator accepted PCP004')
    record('python-validator-foreign')

    def quote(path):
        return "'" + str(path).replace("'", "''") + "'"

    script = out / 'metadata.ps1'
    script.write_text("$ErrorActionPreference='Stop'\n. " +
        quote(root / 'scripts/NexusFPCPackageArtifacts.ps1') + '\n' +
        '$metadata=Read-NexusPackageMetadata ' + quote(metadata) + '\n' +
        "if ($metadata.Name -ne 'NXRTL') { throw 'Wrong name' }\n" +
        'try { $null=Read-NexusPackageMetadata ' + quote(foreign) +
        "; throw 'Foreign metadata accepted' } catch {\n" +
        "if ($_.Exception.Message -notlike '*expected NexusFPC NXP004*') { throw } }\n" +
        "Write-Output 'PASS PowerShell metadata families'\n")
    run('powershell-validator-families', ['powershell.exe', '-NoProfile', '-ExecutionPolicy',
                                        'Bypass', '-File', script], text='PASS PowerShell metadata families')
    print(f'PASS {len(steps)} artifact identity checks: {out}', flush=True)


if __name__ == '__main__':
    main()
