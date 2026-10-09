"""Win64 compiler package-metadata regressions; no production target is enabled."""

import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import zlib


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--source-root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--bootstrap', type=Path,
                        default=Path(r'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\ppcx64.exe'))
    parser.add_argument('--compiler-build', type=Path,
                        help='Incrementally rebuild using an isolated compiler build and its units/')
    parser.add_argument('--output-root', type=Path)
    args = parser.parse_args()
    source = args.source_root.resolve()
    out = args.output_root or Path(tempfile.mkdtemp(prefix='nxpkg-tests-'))
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise RuntimeError('Output directory must be empty')
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
                               f'expected text {text!r}\n{output[-5000:]}\nLog: {log}')
        print('PASS', name, flush=True)
        return output

    build = args.compiler_build or out / 'compiler'
    build.mkdir(exist_ok=True)
    units = build / 'units'
    units.mkdir(exist_ok=True)
    bootstrap_rtl = args.bootstrap.parents[2] / 'units' / 'x86_64-win64' / 'rtl'
    compiler_args = ['-n', '-O1', '-dx86_64', f'-Fu{bootstrap_rtl}',
                     f'-Fu{units}', f'-FU{units}', f'-FE{build}']
    for part in ('', 'x86_64', 'x86', 'systems'):
        compiler_args += [f'-Fu{source / "compiler" / part}',
                          f'-Fi{source / "compiler" / part}']
    candidate = build / 'ppcx64.exe'
    rebuild = [] if args.compiler_build else ['-B']
    run('build-compiler', [args.bootstrap, *rebuild, *compiler_args,
                          '-oppcx64.exe', source / 'compiler' / 'pp.pas'])
    run('build-driver', [args.bootstrap, *compiler_args,
                        source / 'tests' / 'dynamic-packages' / 'package_metadata_test.pas'])
    driver = build / 'package_metadata_test.exe'
    fixtures = out / 'fixtures'
    fixtures.mkdir()
    run('names', [driver, 'names', fixtures], text='PASS names')
    run('disabled-path', [driver, 'disabled', fixtures, 'DoesNotExist'], text='PASS graph 1')

    # Produce a real unit and package with the actual compiler and writer.
    rtl = source / 'rtl' / 'units' / 'x86_64-win64'
    common = ['-n', f'-Fu{rtl}', f'-FU{fixtures}', f'-FE{fixtures}']
    unit = fixtures / 'ux.pas'
    unit.write_text('unit ux;\ninterface\nfunction Marker: LongInt;\n'
                    'implementation\nfunction Marker: LongInt; begin Result:=37; end;\nend.\n')
    run('compile-unit', [candidate, *common, '-Mobjfpc', unit])
    ppu = fixtures / 'ux.ppu'
    original_hash = hashlib.sha256(ppu.read_bytes()).hexdigest()
    run('write-roundtrip', [driver, 'write', fixtures, ppu])
    assert hashlib.sha256(ppu.read_bytes()).hexdigest() == original_hash
    run('read-roundtrip', [driver, 'read', fixtures, 'Fixture'], text='PASS read 1')
    seed = (fixtures / 'Fixture.pcp').read_bytes()
    header_size = 32
    compiler_id, cpu, target = struct.unpack_from('<HHH', seed, 6)

    def entries(data):
        pos = header_size
        end = header_size + struct.unpack_from('<I', data, 16)[0]
        found = {}
        while pos < end:
            size, ident, number = struct.unpack_from('<iBB', data, pos)
            assert size >= 0 and ident == 1
            found[number] = (pos, pos + 6, size)
            pos += 6 + size
        assert pos == end
        return found

    table = entries(seed)[243][1]
    ppu_offset, ppu_size = struct.unpack_from('<ii', seed, table)
    embedded = seed[ppu_offset:ppu_offset + ppu_size]
    assert len(embedded) == ppu_size and embedded[:3] == b'PPU'
    # Independently encode the existing version-3 format, rather than validating
    # the new reader solely against the new writer.
    def short(value):
        data = value.encode('ascii')
        assert len(data) <= 255
        return bytes([len(data)]) + data

    def fixture(name, requirements=(), contained=(), endian='<'):
        payloads = [(93, short(name)), (92, short(name + '.dll')),
                    (244, struct.pack(endian + 'i', len(requirements))),
                    (245, b''.join(short(n) for n in requirements)),
                    (246, struct.pack(endian + 'i', len(contained))),
                    (247, b''.join(short(n) + short(n + '.ppu') for n in contained))]
        crc = 0
        body = bytearray()
        for number, payload in payloads:
            body += struct.pack(endian + 'iBB', len(payload), 1, number) + payload
            crc = zlib.crc32(payload, crc)
        table_start = header_size + len(body) + 6
        body += struct.pack(endian + 'iBB', len(contained) * 8, 1, 243)
        body += bytes(len(contained) * 8)
        body += struct.pack(endian + 'iBB', 0, 1, 255)
        header = struct.pack('<3s3sHHHIIIII', b'PCP', b'003', compiler_id, cpu, target,
                             4 if endian == '>' else 4096, len(body), crc,
                             len(requirements), len(contained))
        data = bytearray(header + body)
        for i in range(len(contained)):
            data += bytes(16 - len(data) % 16)
            offset = len(data)
            data += embedded
            struct.pack_into(endian + 'ii', data, table_start + i * 8, offset, len(embedded))
        data += bytes(16 - len(data) % 16)
        return data

    def save(name, requirements=(), contained=()):
        data = fixture(name, requirements, contained)
        (fixtures / (name + '.pcp')).write_bytes(data)
        return data

    def read_case(label, data, expected=0, text='PASS read'):
        (fixtures / 'Case.pcp').write_bytes(data)
        run(label, [driver, 'read', fixtures, 'Case'], expected=expected, text=text)

    read_case('independent-empty-v3', fixture('Case'))
    read_case('independent-two-units-v3', fixture('Case', contained=['UX', 'UY']))
    read_case('opposite-endian-metadata-v3', fixture('Case', contained=['UX'], endian='>'))
    large = fixture('Case', requirements=[f'Required{i:04}' for i in range(1600)])
    read_case('metadata-over-buffer-boundary', large)

    save('D', contained=['UX'])
    save('B', ['D'])
    save('C', ['d'])
    save('A', ['B', 'C'])
    run('diamond', [driver, 'graph', fixtures, 'A'], text='PASS graph 4')
    save('A', ['a'])
    run('self-cycle', [driver, 'graph', fixtures, 'A'], expected=1,
        text='Circular package dependency: A -> A')
    save('A', ['B'])
    save('B', ['C'])
    save('C', ['a'])
    run('indirect-cycle', [driver, 'graph', fixtures, 'A'], expected=1,
        text='Circular package dependency: A -> B -> C -> A')
    run('building-self-without-pcp', [driver, 'building', fixtures, 'Root', 'root'],
        expected=1, text='Circular package dependency: Root -> root')
    save('B', ['Root'])
    run('building-indirect-without-pcp', [driver, 'building', fixtures, 'Root', 'B'],
        expected=1, text='Circular package dependency: Root -> B -> Root')
    save('B', contained=['UX'])
    save('C', contained=['ux'])
    save('A', ['B', 'C'])
    run('duplicate-owner', [driver, 'graph', fixtures, 'A'], expected=1,
        text='Unit UX is contained in both packages B and C')
    save('A', ['C', 'B'])
    run('duplicate-owner-reversed', [driver, 'graph', fixtures, 'A'], expected=1,
        text='Unit UX is contained in both packages C and B')

    def reject(label, data, text='Invalid PCP file'):
        read_case(label, data, expected=1, text=text)

    base = fixture('Case', contained=['UX', 'UY'])
    offsets = entries(base)
    for length in (0, 1, 6, 19, 31):
        reject('short-header-' + str(length), base[:length], "Can't find package")
    for label, offset, fmt, value in (
        ('bad-magic', 0, 'B', 0), ('bad-version', 3, 'B', ord('9')),
        ('wrong-cpu', 8, 'H', 65535), ('wrong-target', 10, 'H', 65535),
        ('both-endian-flags', 12, 'I', 4100), ('missing-endian-flags', 12, 'I', 0),
        ('oversized-metadata', 16, 'I', 0xffffffff),
        ('negative-header-count', 24, 'i', -1),
    ):
        data = bytearray(base)
        struct.pack_into('<' + fmt, data, offset, value)
        reject(label, data, "Can't find package")
    for number, (start, payload, size) in offsets.items():
        reject(f'truncated-entry-{number}', base[:start + 3], "Can't find package")
    for label, offset, fmt, value in (
        ('negative-entry-size', offsets[93][0], 'i', -1),
        ('huge-entry-size', offsets[93][0], 'i', 0x7fffffff),
        ('wrong-entry-id', offsets[93][0] + 4, 'B', 2),
        ('wrong-entry-number', offsets[93][0] + 5, 'B', 92),
        ('truncated-string', offsets[93][1], 'B', 255),
        ('negative-required-count', offsets[244][1], 'i', -1),
        ('required-count-mismatch', offsets[244][1], 'i', 2),
        ('unit-count-mismatch', offsets[246][1], 'i', 1),
        ('bad-table-size', offsets[243][0], 'i', 8),
        ('bad-checksum', 20, 'I', 0),
        ('offset-in-metadata', offsets[243][1], 'i', 0),
        ('negative-offset', offsets[243][1], 'i', -1),
        ('offset-past-eof', offsets[243][1], 'i', 0x7fffffff),
        ('size-past-eof', offsets[243][1] + 4, 'i', 0x7fffffff),
        ('negative-ppu-size', offsets[243][1] + 4, 'i', -1),
        ('short-ppu-header', offsets[243][1] + 4, 'i', 12),
        ('overlapping-ppus', offsets[243][1] + 8, 'i',
         struct.unpack_from('<i', base, offsets[243][1])[0]),
    ):
        data = bytearray(base)
        struct.pack_into('<' + fmt, data, offset, value)
        reject(label, data)
    reject('renamed-package', fixture('Other'))
    reject('duplicate-required-names', fixture('Case', ['Dep', 'dep']))
    reject('duplicate-contained-names', fixture('Case', contained=['UX', 'ux']))
    reject('empty-required-name', fixture('Case', ['']))
    reject('empty-contained-name', fixture('Case', contained=['']))
    first_ppu = struct.unpack_from('<i', base, offsets[243][1])[0]
    for label, offset, fmt, value in (
        ('ppu-magic', 0, 'B', 0), ('ppu-version', 3, 'B', ord('9')),
        ('ppu-cpu', 8, 'H', 65535), ('ppu-target', 10, 'H', 65535),
        ('ppu-size', 16, 'I', 0xffffffff),
    ):
        data = bytearray(base)
        struct.pack_into('<' + fmt, data, first_ppu + offset, value)
        reject(label, data)
    reject('truncated-embedded-ppu', base[:first_ppu + 40])

    # Consume the real packaged unit with its source, original PPU, and object
    # unavailable. -Cn confines this to compilation, not runtime package support.
    for suffix in ('.pas', '.ppu', '.o'):
        path = fixtures / ('ux' + suffix)
        path.rename(path.with_suffix(suffix + '.hidden'))
    consumer = fixtures / 'consumer.pas'
    consumer.write_text('program consumer; uses ux; begin if Marker<>37 then Halt(1); end.\n')
    # Compile's command-string parser differs from OS argument parsing. A
    # response file also preserves paths containing spaces without truncation.
    response = fixtures / 'consumer.rsp'
    response.write_text('\n'.join(str(x) for x in
                        [*common, '-Cn', '-FPFixture', f'-Fp{fixtures}']))
    run('source-free-pcp-consumption',
        [driver, 'consume', '-n @consumer.rsp consumer.pas'], cwd=fixtures)
    assert not (fixtures / 'ux.ppu').exists()
    assert not (fixtures / 'ux.o').exists()

    conflict = fixtures / 'conflict.ppk'
    conflict.write_text('package conflict; requires Fixture; contains ux; end.\n')
    run('contains-required-unit',
        [driver, 'consume', '-n @consumer.rsp conflict.ppk'], cwd=fixtures,
        expected=1, text='is already contained in package Fixture')

    # The shipped compiler must still refuse package declarations.
    package_source = fixtures / 'unsupported.ppk'
    package_source.write_text('package unsupported; end.\n')
    run('target-remains-disabled', [candidate, *common, package_source], expected=1,
        text='not supported')
    print(f'PASS {len(steps)} steps. Results: {out}', flush=True)


if __name__ == '__main__':
    main()
